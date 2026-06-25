import XCTest
@testable import MusicVizCore

final class AudioAnalyzerTests: XCTestCase {
    func testSilenceReturnsSilentFeatures() {
        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        let features = analyzer.analyze(Array(repeating: 0, count: 2048))
        XCTAssertTrue(features.isSilent)
        XCTAssertEqual(features.overallEnergy, 0, accuracy: 0.0001)
    }

    func testImpulseProducesTransient() {
        var samples = Array(repeating: Float(0), count: 2048)
        samples[128] = 1

        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        _ = analyzer.analyze(Array(repeating: 0, count: 2048))
        let features = analyzer.analyze(samples)

        XCTAssertFalse(features.isSilent)
        XCTAssertGreaterThan(features.transient, 0.2)
        XCTAssertGreaterThan(features.overallEnergy, 0)
    }

    func testLowFrequencySineMapsPrimarilyToBass() {
        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        let features = analyzer.analyze(sineWave(frequency: 90, sampleRate: 48_000))

        XCTAssertFalse(features.isSilent)
        XCTAssertGreaterThan(features.bass, features.mid * 1.5)
        XCTAssertGreaterThan(features.bass, features.high * 3.0)
        XCTAssertLessThan(features.brightness, 0.25)
    }

    func testHighFrequencySineMapsPrimarilyToHighBand() {
        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        let features = analyzer.analyze(sineWave(frequency: 8_000, sampleRate: 48_000))

        XCTAssertFalse(features.isSilent)
        XCTAssertGreaterThan(features.high, features.bass * 3.0)
        XCTAssertGreaterThan(features.high, features.mid * 1.5)
        XCTAssertGreaterThan(features.brightness, 0.45)
    }

    func testVeryShortSamplesDoNotCrash() {
        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        let features = analyzer.analyze([1])

        XCTAssertFalse(features.isSilent)
        XCTAssertGreaterThan(features.overallEnergy, 0)
    }

    func testLowSampleRateDoesNotCrashWhenHighBandIsUnavailable() {
        var analyzer = AudioAnalyzer(sampleRate: 1_000)
        let features = analyzer.analyze(sineWave(frequency: 100, sampleRate: 1_000))

        assertFinite(features)
        XCTAssertFalse(features.isSilent)
    }

    func testNonFiniteSamplesDoNotPoisonLaterAnalysis() {
        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        let contaminated = analyzer.analyze([.nan, .infinity, -.infinity])

        assertFinite(contaminated)
        XCTAssertTrue(contaminated.isSilent)

        let later = analyzer.analyze([1, 0, 0])

        assertFinite(later)
        XCTAssertFalse(later.isSilent)
        XCTAssertGreaterThan(later.overallEnergy, 0)
        XCTAssertGreaterThan(later.transient, 0)
    }

    func testHugeFiniteSamplesProduceFiniteFeatures() {
        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        let features = analyzer.analyze([
            Float.greatestFiniteMagnitude,
            0,
            Float.greatestFiniteMagnitude
        ])

        assertFinite(features)
        XCTAssertFalse(features.isSilent)
        XCTAssertEqual(features.overallEnergy, 1)
        XCTAssertGreaterThanOrEqual(features.brightness, 0)
        XCTAssertLessThanOrEqual(features.brightness, 1)
    }

    private func assertFinite(
        _ features: AudioFeatures,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(features.overallEnergy.isFinite, file: file, line: line)
        XCTAssertTrue(features.bass.isFinite, file: file, line: line)
        XCTAssertTrue(features.lowMid.isFinite, file: file, line: line)
        XCTAssertTrue(features.mid.isFinite, file: file, line: line)
        XCTAssertTrue(features.high.isFinite, file: file, line: line)
        XCTAssertTrue(features.transient.isFinite, file: file, line: line)
        XCTAssertTrue(features.brightness.isFinite, file: file, line: line)
        XCTAssertTrue(features.sustainedIntensity.isFinite, file: file, line: line)
    }

    private func sineWave(
        frequency: Float,
        sampleRate: Float,
        sampleCount: Int = 4096,
        amplitude: Float = 0.6
    ) -> [Float] {
        (0..<sampleCount).map { index in
            let phase = 2 * Float.pi * frequency * Float(index) / sampleRate
            return sin(phase) * amplitude
        }
    }
}
