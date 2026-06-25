import Accelerate
import Foundation

public struct AudioAnalyzer: Sendable {
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

        var squares = [Float](repeating: 0, count: monoSamples.count)
        vDSP_vsq(monoSamples, 1, &squares, 1, vDSP_Length(monoSamples.count))
        var meanSquare: Float = 0
        vDSP_meanv(squares, 1, &meanSquare, vDSP_Length(squares.count))
        let rms = sqrt(meanSquare)
        let energy = min(rms * 8, 1)
        sustained = sustained * 0.92 + energy * 0.08
        let transient = max(0, energy - previousEnergy) * 3.0
        previousEnergy = energy

        let third = max(1, monoSamples.count / 3)
        let bass = bandEnergy(samples: monoSamples, start: 0, end: third)
        let mid = bandEnergy(samples: monoSamples, start: third, end: third * 2)
        let high = bandEnergy(samples: monoSamples, start: third * 2, end: monoSamples.count)
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

    private func bandEnergy(samples: [Float], start: Int, end: Int) -> Float {
        let lowerBound = min(max(start, 0), samples.count)
        let upperBound = min(max(end, lowerBound), samples.count)
        guard lowerBound < upperBound else { return 0 }

        let bandSamples = Array(samples[lowerBound..<upperBound])
        var squares = [Float](repeating: 0, count: bandSamples.count)
        vDSP_vsq(bandSamples, 1, &squares, 1, vDSP_Length(bandSamples.count))
        var mean: Float = 0
        vDSP_meanv(squares, 1, &mean, vDSP_Length(squares.count))
        return sqrt(mean)
    }
}
