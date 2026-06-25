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

    func testVeryShortSamplesDoNotCrash() {
        var analyzer = AudioAnalyzer(sampleRate: 48_000)
        let features = analyzer.analyze([1])

        XCTAssertFalse(features.isSilent)
        XCTAssertGreaterThan(features.overallEnergy, 0)
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
}
