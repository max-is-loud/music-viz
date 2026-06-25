import AudioToolbox
import CoreAudio
import Foundation

public final class SystemAudioTap: AudioInputSource {
    private let queue = DispatchQueue(label: "MusicVizCore.SystemAudioTap")
    private let stateLock = NSLock()

    private var analyzer = AudioAnalyzer(sampleRate: 48_000)
    private var sampleScratch: [Float] = []
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var isRunning = false

    private var storedFeatures = AudioFeatures.silence
    private var storedStatusText = "System audio stopped"
    private var storedIsUsingFallback = false

    public init() {}

    deinit {
        stop()
    }

    public var latestFeatures: AudioFeatures {
        stateLock.withLock { storedFeatures }
    }

    public var statusText: String {
        stateLock.withLock { storedStatusText }
    }

    public var isUsingFallback: Bool {
        stateLock.withLock { storedIsUsingFallback }
    }

    public func start() {
        queue.sync {
            guard isRunning == false else { return }

            updateState(statusText: "System audio waiting", isUsingFallback: false)
            do {
                tapID = try createTap()
                let tapUID = try readTapUID(from: tapID)
                let tapFormat = try readTapFormat(from: tapID)
                try validateTapFormat(tapFormat)

                analyzer = AudioAnalyzer(sampleRate: Float(tapFormat.mSampleRate))
                aggregateID = try createAggregateDevice(tapUID: tapUID)
                ioProcID = try createIOProc(for: aggregateID)
                try check(AudioDeviceStart(aggregateID, ioProcID), operation: "AudioDeviceStart")

                isRunning = true
                updateState(
                    features: .silence,
                    statusText: "System audio active",
                    isUsingFallback: false
                )
            } catch {
                cleanup()
                updateState(
                    features: .silence,
                    statusText: "System audio unavailable",
                    isUsingFallback: true
                )
            }
        }
    }

    public func stop() {
        queue.sync {
            cleanup()
            updateState(
                features: .silence,
                statusText: "System audio stopped",
                isUsingFallback: false
            )
        }
    }

    private func createTap() throws -> AudioObjectID {
        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.name = "MusicViz System Audio Tap"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var objectID = AudioObjectID(kAudioObjectUnknown)
        try check(
            AudioHardwareCreateProcessTap(description, &objectID),
            operation: "AudioHardwareCreateProcessTap"
        )
        return objectID
    }

    private func readTapUID(from objectID: AudioObjectID) throws -> CFString {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        var uid: CFString?
        let status = withUnsafeMutablePointer(to: &uid) { pointer in
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &dataSize,
                pointer
            )
        }
        try check(status, operation: "AudioObjectGetPropertyData(kAudioTapPropertyUID)")

        guard let uid else {
            throw SystemAudioTapError.missingTapUID
        }
        return uid
    }

    private func readTapFormat(from objectID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var format = AudioStreamBasicDescription()
        let status = withUnsafeMutablePointer(to: &format) { pointer in
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &dataSize,
                pointer
            )
        }
        try check(status, operation: "AudioObjectGetPropertyData(kAudioTapPropertyFormat)")
        return format
    }

    private func validateTapFormat(_ format: AudioStreamBasicDescription) throws {
        let isPCM = format.mFormatID == kAudioFormatLinearPCM
        let isFloat = (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let isSupportedWidth = format.mBitsPerChannel == 32
        let hasUsableRate = format.mSampleRate.isFinite && format.mSampleRate > 0

        guard isPCM, isFloat, isSupportedWidth, hasUsableRate else {
            throw SystemAudioTapError.unsupportedFormat(format)
        }
    }

    private func createAggregateDevice(tapUID: CFString) throws -> AudioObjectID {
        let aggregateUID = "com.maxlanglois-morin.music-viz.aggregate.\(UUID().uuidString)" as CFString
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MusicViz System Audio Aggregate",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUID
                ] as [String: Any]
            ]
        ]

        var objectID = AudioObjectID(kAudioObjectUnknown)
        try check(
            AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &objectID),
            operation: "AudioHardwareCreateAggregateDevice"
        )
        return objectID
    }

    private func createIOProc(for deviceID: AudioObjectID) throws -> AudioDeviceIOProcID {
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, queue) { [weak self] _, inputData, _, _, _ in
            self?.handleInput(inputData)
        }
        try check(status, operation: "AudioDeviceCreateIOProcIDWithBlock")

        guard let procID else {
            throw SystemAudioTapError.missingIOProcID
        }
        return procID
    }

    private func handleInput(_ inputData: UnsafePointer<AudioBufferList>) {
        let requiredCapacity = reduceBuffers(in: inputData, into: 0) { partialResult, buffer in
            partialResult + Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
        }
        guard requiredCapacity > 0 else {
            updateState(features: .silence)
            return
        }

        sampleScratch.removeAll(keepingCapacity: true)
        if sampleScratch.capacity < requiredCapacity {
            sampleScratch.reserveCapacity(requiredCapacity)
        }

        forEachBuffer(in: inputData) { buffer in
            guard let data = buffer.mData else { return }
            let sampleCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
            let samples = UnsafeBufferPointer<Float>(
                start: data.assumingMemoryBound(to: Float.self),
                count: sampleCount
            )
            sampleScratch.append(contentsOf: samples)
        }

        guard sampleScratch.isEmpty == false else {
            updateState(features: .silence)
            return
        }

        let features = analyzer.analyze(sampleScratch)
        updateState(features: features, statusText: "System audio active")
    }

    private func reduceBuffers<Result>(
        in inputData: UnsafePointer<AudioBufferList>,
        into initialResult: Result,
        _ updateAccumulatingResult: (Result, AudioBuffer) -> Result
    ) -> Result {
        var result = initialResult
        forEachBuffer(in: inputData) { buffer in
            result = updateAccumulatingResult(result, buffer)
        }
        return result
    }

    private func forEachBuffer(
        in inputData: UnsafePointer<AudioBufferList>,
        _ body: (AudioBuffer) -> Void
    ) {
        let bufferCount = Int(inputData.pointee.mNumberBuffers)
        withUnsafePointer(to: inputData.pointee.mBuffers) { firstBufferPointer in
            let bufferPointer = UnsafeRawPointer(firstBufferPointer)
                .assumingMemoryBound(to: AudioBuffer.self)
            for index in 0..<bufferCount {
                body(bufferPointer[index])
            }
        }
    }

    private func cleanup() {
        if let ioProcID {
            _ = AudioDeviceStop(aggregateID, ioProcID)
            _ = AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            self.ioProcID = nil
        }

        if aggregateID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }

        if tapID != kAudioObjectUnknown {
            _ = AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }

        sampleScratch.removeAll(keepingCapacity: true)
        isRunning = false
    }

    private func updateState(
        features: AudioFeatures? = nil,
        statusText: String? = nil,
        isUsingFallback: Bool? = nil
    ) {
        stateLock.withLock {
            if let features {
                storedFeatures = features
            }
            if let statusText {
                storedStatusText = statusText
            }
            if let isUsingFallback {
                storedIsUsingFallback = isUsingFallback
            }
        }
    }

    private func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw SystemAudioTapError.coreAudio(operation: operation, status: status)
        }
    }
}

public enum AudioSourceFactory {
    public static func makeDefaultSource() -> AudioInputSource {
        let systemTap = SystemAudioTap()
        systemTap.start()
        if systemTap.isUsingFallback {
            let fallback = SyntheticAudioSource()
            fallback.start()
            return fallback
        }
        return systemTap
    }
}

private enum SystemAudioTapError: Error {
    case coreAudio(operation: String, status: OSStatus)
    case missingIOProcID
    case missingTapUID
    case unsupportedFormat(AudioStreamBasicDescription)
}
