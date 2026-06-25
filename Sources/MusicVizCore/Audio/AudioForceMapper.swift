import Foundation

public enum AudioForceMapper {
    public static func map(_ features: AudioFeatures, parameters: SimulationParameters) -> AudioInjection {
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

        let influence = sanitizedInfluence(parameters.audioInfluence)
        let overallEnergy = sanitizedFeature(features.overallEnergy)
        let bass = sanitizedFeature(features.bass)
        let mid = sanitizedFeature(features.mid)
        let high = sanitizedFeature(features.high)
        let transient = sanitizedFeature(features.transient)
        let brightness = sanitizedFeature(features.brightness)
        let sustainedIntensity = sanitizedFeature(features.sustainedIntensity)

        return AudioInjection(
            timeScaleMultiplier: 0.65 + sustainedIntensity * 1.6,
            compressionStrength: bass * influence,
            shockwaveStrength: bass * transient * influence,
            heatInput: sustainedIntensity * influence,
            turbulenceInput: (mid + high * 0.6) * influence,
            radiationInput: (high + brightness * 0.5) * influence,
            coolingBias: max(0, 0.08 - overallEnergy * 0.08)
        )
    }
}

private func sanitizedFeature(_ value: Float) -> Float {
    guard value.isFinite else { return 0 }
    return min(max(value, 0), 1)
}

private func sanitizedInfluence(_ value: Float) -> Float {
    guard value.isFinite else { return 0 }
    return min(max(value, 0), 3)
}
