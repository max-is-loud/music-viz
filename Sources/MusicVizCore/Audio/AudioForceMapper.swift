import Foundation

public enum AudioForceMapper {
    public static func map(_ features: AudioFeatures, parameters: SimulationParameters) -> AudioInjection {
        let influence = parameters.audioInfluence
        if features.isSilent {
            return AudioInjection(
                timeScaleMultiplier: 0.18,
                compressionStrength: 0,
                shockwaveStrength: 0,
                heatInput: 0,
                turbulenceInput: 0.03,
                radiationInput: 0,
                coolingBias: 0.18
            )
        }

        return AudioInjection(
            timeScaleMultiplier: 0.65 + features.sustainedIntensity * 1.6,
            compressionStrength: features.bass * influence,
            shockwaveStrength: features.bass * features.transient * influence,
            heatInput: features.sustainedIntensity * influence,
            turbulenceInput: (features.mid + features.high * 0.6) * influence,
            radiationInput: (features.high + features.brightness * 0.5) * influence,
            coolingBias: max(0, 0.08 - features.overallEnergy * 0.08)
        )
    }
}
