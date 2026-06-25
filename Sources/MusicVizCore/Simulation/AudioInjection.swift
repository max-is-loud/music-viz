import Foundation

public struct AudioInjection: Equatable, Sendable {
    public var timeScaleMultiplier: Float
    public var compressionStrength: Float
    public var shockwaveStrength: Float
    public var heatInput: Float
    public var turbulenceInput: Float
    public var radiationInput: Float
    public var coolingBias: Float

    public init(
        timeScaleMultiplier: Float,
        compressionStrength: Float,
        shockwaveStrength: Float,
        heatInput: Float,
        turbulenceInput: Float,
        radiationInput: Float,
        coolingBias: Float
    ) {
        self.timeScaleMultiplier = timeScaleMultiplier
        self.compressionStrength = compressionStrength
        self.shockwaveStrength = shockwaveStrength
        self.heatInput = heatInput
        self.turbulenceInput = turbulenceInput
        self.radiationInput = radiationInput
        self.coolingBias = coolingBias
    }
}
