import Foundation

public struct AudioAnalyzer: Sendable {
    private static let sampleMagnitudeLimit: Float = 16

    private let sampleRate: Float
    private var previousEnergy: Float = 0
    private var sustained: Float = 0

    public init(sampleRate: Float) {
        self.sampleRate = sampleRate
    }

    public mutating func analyze(_ monoSamples: [Float]) -> AudioFeatures {
        guard monoSamples.isEmpty == false else {
            return .silence
        }

        var totalSquares: Float = 0
        var bassSquares: Float = 0
        var midSquares: Float = 0
        var highSquares: Float = 0
        var bassCount = 0
        var midCount = 0
        var highCount = 0

        let third = max(1, monoSamples.count / 3)
        for (index, sample) in monoSamples.enumerated() {
            let boundedSample = sanitizedSample(sample)
            let square = boundedSample * boundedSample
            totalSquares += square

            if index < third {
                bassSquares += square
                bassCount += 1
            } else if index < third * 2 {
                midSquares += square
                midCount += 1
            } else {
                highSquares += square
                highCount += 1
            }
        }

        let meanSquare = totalSquares / Float(monoSamples.count)
        let rms = sqrt(meanSquare)
        let energy = min(rms * 8, 1)
        sustained = sustained * 0.92 + energy * 0.08
        let transient = max(0, energy - previousEnergy) * 3.0
        previousEnergy = energy

        let bass = bandEnergy(squareSum: bassSquares, count: bassCount)
        let mid = bandEnergy(squareSum: midSquares, count: midCount)
        let high = bandEnergy(squareSum: highSquares, count: highCount)
        let brightness = min(1, high / max(0.0001, bass + mid + high))

        return AudioFeatures(
            overallEnergy: energy,
            bass: min(bass * 8, 1),
            lowMid: min((bass + mid) * 4, 1),
            mid: min(mid * 8, 1),
            high: min(high * 8, 1),
            transient: min(transient, 1),
            brightness: brightness,
            sustainedIntensity: sustained,
            isSilent: energy < 0.01
        )
    }

    private func bandEnergy(squareSum: Float, count: Int) -> Float {
        guard count > 0 else { return 0 }
        return sqrt(squareSum / Float(count))
    }

    private func sanitizedSample(_ sample: Float) -> Float {
        guard sample.isFinite else { return 0 }
        return min(max(sample, -Self.sampleMagnitudeLimit), Self.sampleMagnitudeLimit)
    }
}
