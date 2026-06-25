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
}
