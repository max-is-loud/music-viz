import Foundation

public struct SimulationParameters: Equatable, Sendable {
    public var timeScale: Float
    public var audioInfluence: Float
    public var particleCountTarget: Int
    public var fieldResolution: Int
    public var gravityStrength: Float
    public var heatDecay: Float
    public var turbulenceStrength: Float
    public var starIgnitionThreshold: Float
    public var collapseThreshold: Float
    public var renderIntensity: Float
    public var bloomStrength: Float

    public init(
        timeScale: Float = 1.0,
        audioInfluence: Float = 1.0,
        particleCountTarget: Int = 250_000,
        fieldResolution: Int = 512,
        gravityStrength: Float = 1.0,
        heatDecay: Float = 0.985,
        turbulenceStrength: Float = 0.35,
        starIgnitionThreshold: Float = 0.72,
        collapseThreshold: Float = 0.92,
        renderIntensity: Float = 1.0,
        bloomStrength: Float = 0.8
    ) {
        self.timeScale = timeScale
        self.audioInfluence = audioInfluence
        self.particleCountTarget = particleCountTarget
        self.fieldResolution = fieldResolution
        self.gravityStrength = gravityStrength
        self.heatDecay = heatDecay
        self.turbulenceStrength = turbulenceStrength
        self.starIgnitionThreshold = starIgnitionThreshold
        self.collapseThreshold = collapseThreshold
        self.renderIntensity = renderIntensity
        self.bloomStrength = bloomStrength
    }

    public func clamped() -> SimulationParameters {
        SimulationParameters(
            timeScale: timeScale.clamped(to: 0.02...8.0),
            audioInfluence: audioInfluence.clamped(to: 0.0...3.0),
            particleCountTarget: particleCountTarget.clamped(to: 1_024...2_000_000),
            fieldResolution: nearestPowerOfTwo(fieldResolution).clamped(to: 128...2048),
            gravityStrength: gravityStrength.clamped(to: 0.0...5.0),
            heatDecay: heatDecay.clamped(to: 0.80...0.999),
            turbulenceStrength: turbulenceStrength.clamped(to: 0.0...4.0),
            starIgnitionThreshold: starIgnitionThreshold.clamped(to: 0.01...2.0),
            collapseThreshold: collapseThreshold.clamped(to: 0.01...4.0),
            renderIntensity: renderIntensity.clamped(to: 0.0...5.0),
            bloomStrength: bloomStrength.clamped(to: 0.0...3.0)
        )
    }
}

private func nearestPowerOfTwo(_ value: Int) -> Int {
    guard value > 1 else { return 1 }
    let lower = 1 << Int(floor(log2(Double(value))))
    let upper = lower << 1
    return (value - lower) < (upper - value) ? lower : upper
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
