import Foundation

public struct SeededRandom: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x4d595a56495a0001 : seed
    }

    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func nextFloat() -> Float {
        Float(nextUInt64() >> 40) / Float(1 << 24)
    }

    public mutating func nextSignedFloat() -> Float {
        nextFloat() * 2 - 1
    }
}
