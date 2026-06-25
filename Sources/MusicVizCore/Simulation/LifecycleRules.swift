import Foundation

public struct LifecycleSample: Equatable, Sendable {
    public var kind: ParticleKind
    public var mass: Float
    public var temperature: Float
    public var age: Float
    public var localDensity: Float

    public init(kind: ParticleKind, mass: Float, temperature: Float, age: Float, localDensity: Float) {
        self.kind = kind
        self.mass = mass
        self.temperature = temperature
        self.age = age
        self.localDensity = localDensity
    }
}

public enum LifecycleRules {
    public static func nextKind(_ sample: LifecycleSample, parameters: SimulationParameters) -> ParticleKind {
        switch sample.kind {
        case .dust, .plasma:
            if sample.localDensity >= parameters.starIgnitionThreshold,
               sample.temperature >= 0.55,
               sample.mass >= 1.2 {
                return .protostar
            }
            return sample.kind
        case .protostar:
            if sample.temperature >= 0.9 && sample.age >= 8 {
                return .star
            }
            return .protostar
        case .star:
            if sample.temperature >= 2.0 && sample.mass >= 2.8 && sample.age >= 40 {
                return .unstableStar
            }
            return .star
        case .unstableStar:
            if sample.localDensity >= parameters.collapseThreshold || sample.temperature >= 2.4 {
                return .remnant
            }
            return .unstableStar
        case .remnant, .ejecta:
            return sample.kind
        }
    }
}
