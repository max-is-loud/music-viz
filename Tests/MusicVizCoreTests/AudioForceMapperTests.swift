import XCTest
@testable import MusicVizCore

final class AudioForceMapperTests: XCTestCase {
    func testSilenceCreatesSimmerInjection() {
        let injection = AudioForceMapper.map(.silence, parameters: .init())
        XCTAssertLessThan(injection.timeScaleMultiplier, 1)
        XCTAssertEqual(injection.shockwaveStrength, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(injection.coolingBias, 0)
    }

    func testBassAndTransientCreateShockwave() {
        let features = AudioFeatures(
            overallEnergy: 0.8,
            bass: 0.9,
            lowMid: 0.4,
            mid: 0.2,
            high: 0.1,
            transient: 0.7,
            brightness: 0.2,
            sustainedIntensity: 0.8,
            isSilent: false
        )
        let injection = AudioForceMapper.map(features, parameters: .init(audioInfluence: 1.5))
        XCTAssertGreaterThan(injection.shockwaveStrength, 0.8)
        XCTAssertGreaterThan(injection.compressionStrength, 0.9)
        XCTAssertGreaterThan(injection.heatInput, 0.5)
    }
}
