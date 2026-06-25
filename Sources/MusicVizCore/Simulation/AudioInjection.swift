import Foundation

public struct AudioInjection: Equatable, Sendable {
    public var timeScaleMultiplier: Float
    public var compressionStrength: Float
    public var shockwaveStrength: Float
    public var heatInput: Float
    public var turbulenceInput: Float
    public var radiationInput: Float
    public var coolingBias: Float
}
