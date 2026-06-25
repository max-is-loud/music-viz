import XCTest
@testable import MusicVizCore

final class AudioInputSourceTests: XCTestCase {
    func testSyntheticAudioSourceProvidesAnimatedFallbackFeatures() {
        let source: AudioInputSource = SyntheticAudioSource()

        source.start()
        let features = source.latestFeatures

        XCTAssertEqual(source.statusText, "Synthetic audio")
        XCTAssertTrue(source.isUsingFallback)
        XCTAssertFalse(features.isSilent)
        XCTAssertGreaterThanOrEqual(features.overallEnergy, 0)
        XCTAssertLessThanOrEqual(features.overallEnergy, 0.35)
        XCTAssertGreaterThanOrEqual(features.bass, 0)
        XCTAssertLessThanOrEqual(features.bass, 0.45)
    }
}
