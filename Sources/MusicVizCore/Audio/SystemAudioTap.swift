import AudioToolbox
import CoreAudio
import Darwin
import Foundation

public final class SystemAudioTap: AudioInputSource {
    private static let sampleHandoffCapacity = 4096

    private let controlQueue = SystemAudioTapControlQueue(label: "MusicVizCore.SystemAudioTap.Control")
    private let ioProcQueue = SystemAudioTapDispatchQueue(label: "MusicVizCore.SystemAudioTap.IOProc")
    private let analysisQueue = DispatchQueue(label: "MusicVizCore.SystemAudioTap.Analysis")
    private let stateLock = NSLock()
    private let sampleHandoff = AudioSampleHandoff(capacity: sampleHandoffCapacity)

    private var analyzer = AudioAnalyzer(sampleRate: 48_000)
    private var analysisScratch: [Float] = []
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
        controlQueue.sync {
            guard isRunning == false else { return }

            updateState(statusText: "System audio waiting for output", isUsingFallback: false)
            do {
                tapID = try createTap()
                let tapUID = try readTapUID(from: tapID)
                let tapFormat = try readTapFormat(from: tapID)
                try validateTapFormat(tapFormat)

                resetAnalysisState(sampleRate: Float(tapFormat.mSampleRate))
                aggregateID = try createAggregateDevice(tapUID: tapUID)
                ioProcID = try createIOProc(for: aggregateID)
                try check(AudioDeviceStart(aggregateID, ioProcID), operation: "AudioDeviceStart")

                isRunning = true
                updateState(
                    features: .silence,
                    statusText: "System audio waiting for output",
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
        let stopWork: @Sendable () -> Void = { [self] in
            cleanup()
            updateState(
                features: .silence,
                statusText: "System audio stopped",
                isUsingFallback: false
            )
        }

        if ioProcQueue.isCurrent {
            controlQueue.async(stopWork)
            return
        }

        controlQueue.sync(stopWork)
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
        let aggregateDescription = SystemAudioTapConfiguration.aggregateDescription(tapUID: tapUID)

        var objectID = AudioObjectID(kAudioObjectUnknown)
        try check(
            AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &objectID),
            operation: "AudioHardwareCreateAggregateDevice"
        )
        return objectID
    }

    private func createIOProc(for deviceID: AudioObjectID) throws -> AudioDeviceIOProcID {
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, ioProcQueue.dispatchQueue) { [weak self] _, inputData, _, _, _ in
            self?.handleInput(inputData)
        }
        try check(status, operation: "AudioDeviceCreateIOProcIDWithBlock")

        guard let procID else {
            throw SystemAudioTapError.missingIOProcID
        }
        return procID
    }

    private func handleInput(_ inputData: UnsafePointer<AudioBufferList>) {
        let result = sampleHandoff.copyFromCallback(inputData)
        guard result.sampleCount > 0, result.shouldScheduleAnalysis else {
            return
        }

        analysisQueue.async { [weak self] in
            self?.processPendingSamples()
        }
    }

    private func processPendingSamples() {
        guard sampleHandoff.drainForAnalysis(into: &analysisScratch) else {
            return
        }

        let features = analyzer.analyze(analysisScratch)
        updateState(features: features, statusText: "System audio active")
    }

    private func resetAnalysisState(sampleRate: Float) {
        sampleHandoff.reset()
        analysisQueue.sync {
            analyzer = AudioAnalyzer(sampleRate: sampleRate)
            analysisScratch.removeAll(keepingCapacity: true)
        }
    }

    private func cleanup() {
        if let ioProcID, aggregateID != kAudioObjectUnknown {
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

        resetAnalysisState(sampleRate: 48_000)
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

extension SystemAudioTap: @unchecked Sendable {}

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

enum SystemAudioTapConfiguration {
    static func aggregateDescription(tapUID: CFString) -> [String: Any] {
        let aggregateUID = "com.maxlanglois-morin.music-viz.aggregate.\(UUID().uuidString)"
        return [
            kAudioAggregateDeviceNameKey: "MusicViz System Audio Aggregate",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: false,
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tapUID as String
                ] as [String: Any]
            ]
        ]
    }
}

final class SystemAudioTapControlQueue {
    private let queue: DispatchQueue
    private let key = DispatchSpecificKey<Void>()

    init(label: String) {
        queue = DispatchQueue(label: label)
        queue.setSpecific(key: key, value: ())
    }

    func sync<T>(_ work: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: key) != nil {
            return try work()
        }
        return try queue.sync(execute: work)
    }

    func async(_ work: @escaping @Sendable () -> Void) {
        queue.async(execute: work)
    }
}

extension SystemAudioTapControlQueue: @unchecked Sendable {}

final class SystemAudioTapDispatchQueue {
    let dispatchQueue: DispatchQueue

    private let key = DispatchSpecificKey<Void>()

    init(label: String) {
        dispatchQueue = DispatchQueue(label: label)
        dispatchQueue.setSpecific(key: key, value: ())
    }

    var isCurrent: Bool {
        DispatchQueue.getSpecific(key: key) != nil
    }

    func async(_ work: @escaping @Sendable () -> Void) {
        dispatchQueue.async(execute: work)
    }
}

extension SystemAudioTapDispatchQueue: @unchecked Sendable {}

struct AudioSampleHandoffCallbackResult {
    var sampleCount: Int
    var shouldScheduleAnalysis: Bool
}

final class AudioSampleHandoff {
    private static let sampleMagnitudeLimit: Float = 16

    private var mutex = pthread_mutex_t()
    private var storage: [Float]
    private var count = 0
    private var isAnalysisScheduled = false

    init(capacity: Int) {
        storage = Array(repeating: 0, count: max(0, capacity))
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    var capacity: Int {
        storage.count
    }

    func copyFromCallback(_ samples: [Float]) -> Int {
        lock()
        defer { unlock() }

        count = copy(samples, into: &storage)
        isAnalysisScheduled = count > 0
        return count
    }

    func copyFromCallback(_ inputData: UnsafePointer<AudioBufferList>) -> AudioSampleHandoffCallbackResult {
        guard tryLock() else {
            return AudioSampleHandoffCallbackResult(sampleCount: 0, shouldScheduleAnalysis: false)
        }
        defer { unlock() }

        count = copy(inputData, into: &storage)
        let shouldScheduleAnalysis = count > 0 && isAnalysisScheduled == false
        if shouldScheduleAnalysis {
            isAnalysisScheduled = true
        }
        return AudioSampleHandoffCallbackResult(
            sampleCount: count,
            shouldScheduleAnalysis: shouldScheduleAnalysis
        )
    }

    func drainForAnalysis() -> [Float] {
        var samples: [Float] = []
        _ = drainForAnalysis(into: &samples)
        return samples
    }

    func drainForAnalysis(into samples: inout [Float]) -> Bool {
        lock()
        defer { unlock() }

        samples.removeAll(keepingCapacity: true)
        if samples.capacity < count {
            samples.reserveCapacity(count)
        }
        samples.append(contentsOf: storage.prefix(count))

        let hasSamples = count > 0
        count = 0
        isAnalysisScheduled = false
        return hasSamples
    }

    func reset() {
        lock()
        defer { unlock() }

        count = 0
        isAnalysisScheduled = false
    }

    private func copy(_ samples: [Float], into destination: inout [Float]) -> Int {
        let copiedCount = min(samples.count, destination.count)
        for index in 0..<copiedCount {
            destination[index] = sanitizedSample(samples[index])
        }
        return copiedCount
    }

    private func copy(
        _ inputData: UnsafePointer<AudioBufferList>,
        into destination: inout [Float]
    ) -> Int {
        var writeIndex = 0
        forEachBuffer(in: inputData) { buffer in
            guard writeIndex < destination.count, let data = buffer.mData else {
                return
            }

            let sampleCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
            let samples = UnsafeBufferPointer<Float>(
                start: data.assumingMemoryBound(to: Float.self),
                count: sampleCount
            )
            for sample in samples {
                guard writeIndex < destination.count else { break }
                destination[writeIndex] = sanitizedSample(sample)
                writeIndex += 1
            }
        }
        return writeIndex
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

    private func sanitizedSample(_ sample: Float) -> Float {
        guard sample.isFinite else { return 0 }
        return min(max(sample, -Self.sampleMagnitudeLimit), Self.sampleMagnitudeLimit)
    }

    private func lock() {
        pthread_mutex_lock(&mutex)
    }

    private func tryLock() -> Bool {
        pthread_mutex_trylock(&mutex) == 0
    }

    private func unlock() {
        pthread_mutex_unlock(&mutex)
    }
}
