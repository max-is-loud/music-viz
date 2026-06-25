import XCTest
@testable import MusicVizCore

final class AudioFeaturesTests: XCTestCase {
    func testSilenceContainsZeroEnergyFeatures() {
        XCTAssertEqual(
            AudioFeatures.silence,
            AudioFeatures(
                overallEnergy: 0,
                bass: 0,
                lowMid: 0,
                mid: 0,
                high: 0,
                transient: 0,
                brightness: 0,
                sustainedIntensity: 0,
                isSilent: true
            )
        )
    }
}
