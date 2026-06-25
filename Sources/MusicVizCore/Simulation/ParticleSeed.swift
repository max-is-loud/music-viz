import Foundation

public struct SeedParticle: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var vx: Float
    public var vy: Float
    public var mass: Float
    public var temperature: Float
    public var age: Float
    public var kind: UInt32
}

public enum ParticleKind: UInt32, Sendable {
    case dust = 0
    case plasma = 1
    case protostar = 2
    case star = 3
    case unstableStar = 4
    case remnant = 5
    case ejecta = 6
}

public enum ParticleSeed {
    public static func generate(count: Int, seed: UInt64) -> [SeedParticle] {
        var rng = SeededRandom(seed: seed)
        return (0..<count).map { index in
            let radius = sqrt(rng.nextFloat()) * 0.92
            let angle = rng.nextFloat() * Float.pi * 2
            let swirl = Float(index % 17) / 17.0
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            return SeedParticle(
                x: x,
                y: y,
                vx: -y * 0.006 + rng.nextSignedFloat() * 0.002 + swirl * 0.0004,
                vy: x * 0.006 + rng.nextSignedFloat() * 0.002 - swirl * 0.0004,
                mass: 0.4 + rng.nextFloat() * 1.6,
                temperature: rng.nextFloat() * 0.08,
                age: 0,
                kind: rng.nextFloat() > 0.82 ? ParticleKind.plasma.rawValue : ParticleKind.dust.rawValue
            )
        }
    }
}
