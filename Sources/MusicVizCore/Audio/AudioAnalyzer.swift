import Accelerate
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

        let samples = monoSamples.map(sanitizedSample)
        var totalSquares: Float = 0
        for boundedSample in samples {
            let square = boundedSample * boundedSample
            totalSquares += square
        }

        let meanSquare = totalSquares / Float(samples.count)
        let rms = sqrt(meanSquare)
        let energy = min(rms * 8, 1)
        sustained = sustained * 0.92 + energy * 0.08
        let transient = max(0, energy - previousEnergy) * 3.0
        previousEnergy = energy

        let spectrum = spectrumPowers(for: samples)
        let bassPower = bandPower(in: spectrum, frequencyRange: 20...250)
        let lowMidPower = bandPower(in: spectrum, frequencyRange: 250...500)
        let midPower = bandPower(in: spectrum, frequencyRange: 500...4_000)
        let highPower = nyquistFrequency >= 4_000
            ? bandPower(in: spectrum, frequencyRange: 4_000...nyquistFrequency)
            : 0
        let totalBandPower = max(bassPower + lowMidPower + midPower + highPower, 0.0001)
        let bass = normalizedBandEnergy(power: bassPower, totalPower: totalBandPower, overallEnergy: energy)
        let lowMid = normalizedBandEnergy(power: lowMidPower, totalPower: totalBandPower, overallEnergy: energy)
        let mid = normalizedBandEnergy(power: midPower, totalPower: totalBandPower, overallEnergy: energy)
        let high = normalizedBandEnergy(power: highPower, totalPower: totalBandPower, overallEnergy: energy)
        let brightness = min(1, highPower / totalBandPower)

        return AudioFeatures(
            overallEnergy: energy,
            bass: bass,
            lowMid: lowMid,
            mid: mid,
            high: high,
            transient: min(transient, 1),
            brightness: brightness,
            sustainedIntensity: sustained,
            isSilent: energy < 0.01
        )
    }

    private var nyquistFrequency: Float {
        max(0, sampleRate * 0.5)
    }

    private func spectrumPowers(for samples: [Float]) -> [Float] {
        let fftSize = fftSize(forSampleCount: samples.count)
        let halfSize = fftSize / 2
        guard halfSize > 0,
              let setup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2)) else {
            return []
        }
        defer {
            vDSP_destroy_fftsetup(setup)
        }

        var windowed = Array(repeating: Float(0), count: fftSize)
        var window = Array(repeating: Float(0), count: samples.count)
        vDSP_hann_window(&window, vDSP_Length(samples.count), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(samples.count))

        var real = Array(repeating: Float(0), count: halfSize)
        var imaginary = Array(repeating: Float(0), count: halfSize)
        var powers = Array(repeating: Float(0), count: halfSize)

        real.withUnsafeMutableBufferPointer { realBuffer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                guard let realBase = realBuffer.baseAddress,
                      let imaginaryBase = imaginaryBuffer.baseAddress else {
                    return
                }

                var split = DSPSplitComplex(realp: realBase, imagp: imaginaryBase)
                windowed.withUnsafeBufferPointer { pointer in
                    pointer.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complex in
                        vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }

                vDSP_fft_zrip(
                    setup,
                    &split,
                    1,
                    vDSP_Length(log2(Float(fftSize))),
                    FFTDirection(FFT_FORWARD)
                )
                vDSP_zvmags(&split, 1, &powers, 1, vDSP_Length(halfSize))
            }
        }

        if powers.isEmpty == false {
            powers[0] = 0
        }
        return powers
    }

    private func fftSize(forSampleCount count: Int) -> Int {
        let target = max(2, count)
        return 1 << Int(ceil(log2(Double(target))))
    }

    private func bandPower(in powers: [Float], frequencyRange: ClosedRange<Float>) -> Float {
        guard powers.isEmpty == false, sampleRate > 0 else { return 0 }

        let fftSize = powers.count * 2
        let binWidth = sampleRate / Float(fftSize)
        var sum: Float = 0

        for (index, power) in powers.enumerated() {
            let frequency = Float(index) * binWidth
            if frequencyRange.contains(frequency), power.isFinite {
                sum += max(0, power)
            }
        }
        return sum
    }

    private func normalizedBandEnergy(power: Float, totalPower: Float, overallEnergy: Float) -> Float {
        guard power.isFinite, totalPower > 0, overallEnergy > 0 else { return 0 }
        let share = min(max(power / totalPower, 0), 1)
        return min(1, sqrt(share) * overallEnergy * 1.4)
    }

    private func sanitizedSample(_ sample: Float) -> Float {
        guard sample.isFinite else { return 0 }
        return min(max(sample, -Self.sampleMagnitudeLimit), Self.sampleMagnitudeLimit)
    }
}
