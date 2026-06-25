import Foundation

public final class SyntheticAudioSource: AudioInputSource {
    private var startTime = Date()

    public init() {}

    public var latestFeatures: AudioFeatures {
        let t = Float(Date().timeIntervalSince(startTime))
        let pulse = (sin(t * 2.1) + 1) * 0.5
        return AudioFeatures(
            overallEnergy: pulse * 0.35,
            bass: pulse * 0.45,
            lowMid: pulse * 0.25,
            mid: 0.15,
            high: 0.08,
            transient: pulse > 0.92 ? 0.7 : 0,
            brightness: 0.2,
            sustainedIntensity: pulse * 0.3,
            isSilent: false
        )
    }

    public var statusText: String { "Synthetic audio" }
    public var isUsingFallback: Bool { true }
    public func start() { startTime = Date() }
    public func stop() {}
}
