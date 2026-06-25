import Foundation

public struct AudioFeatures: Equatable, Sendable {
    public var overallEnergy: Float
    public var bass: Float
    public var lowMid: Float
    public var mid: Float
    public var high: Float
    public var transient: Float
    public var brightness: Float
    public var sustainedIntensity: Float
    public var isSilent: Bool

    public static let silence = AudioFeatures(
        overallEnergy: 0,
        bass: 0,
        lowMid: 0,
        mid: 0,
        high: 0,
        transient: 0,
        brightness: 0,
        sustainedIntensity: 0,
        isSilent: true
    )

    public init(
        overallEnergy: Float,
        bass: Float,
        lowMid: Float,
        mid: Float,
        high: Float,
        transient: Float,
        brightness: Float,
        sustainedIntensity: Float,
        isSilent: Bool
    ) {
        self.overallEnergy = overallEnergy
        self.bass = bass
        self.lowMid = lowMid
        self.mid = mid
        self.high = high
        self.transient = transient
        self.brightness = brightness
        self.sustainedIntensity = sustainedIntensity
        self.isSilent = isSilent
    }
}
