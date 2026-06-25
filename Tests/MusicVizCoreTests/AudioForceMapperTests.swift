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

    func testInvalidInputsProduceFiniteNonNegativeInjectionValues() {
        let features = AudioFeatures(
            overallEnergy: .nan,
            bass: -.infinity,
            lowMid: -0.5,
            mid: .infinity,
            high: .nan,
            transient: 2,
            brightness: -1,
            sustainedIntensity: .infinity,
            isSilent: false
        )

        for influence in [Float.nan, -.infinity, -2, .infinity, 100] {
            let injection = AudioForceMapper.map(features, parameters: .init(audioInfluence: influence))
            XCTAssertFiniteAndNonNegative(injection, influence: influence)
        }
    }

    func testInvalidInfluenceDefaultsToZeroAndHugeInfluenceClamps() {
        let features = AudioFeatures(
            overallEnergy: 0.4,
            bass: 0.5,
            lowMid: 0.2,
            mid: 0.25,
            high: 0.5,
            transient: 0.75,
            brightness: 0.4,
            sustainedIntensity: 0.6,
            isSilent: false
        )

        for influence in [Float.nan, -Float.infinity, -1] {
            let injection = AudioForceMapper.map(features, parameters: .init(audioInfluence: influence))
            XCTAssertEqual(injection.compressionStrength, 0, accuracy: 0.0001)
            XCTAssertEqual(injection.shockwaveStrength, 0, accuracy: 0.0001)
            XCTAssertEqual(injection.heatInput, 0, accuracy: 0.0001)
            XCTAssertEqual(injection.turbulenceInput, 0, accuracy: 0.0001)
            XCTAssertEqual(injection.radiationInput, 0, accuracy: 0.0001)
        }

        let injection = AudioForceMapper.map(features, parameters: .init(audioInfluence: 100))
        XCTAssertEqual(injection.compressionStrength, 1.5, accuracy: 0.0001)
        XCTAssertEqual(injection.shockwaveStrength, 1.125, accuracy: 0.0001)
        XCTAssertEqual(injection.heatInput, 1.8, accuracy: 0.0001)
        XCTAssertEqual(injection.turbulenceInput, 1.65, accuracy: 0.0001)
        XCTAssertEqual(injection.radiationInput, 2.1, accuracy: 0.0001)
    }

    private func XCTAssertFiniteAndNonNegative(
        _ injection: AudioInjection,
        influence: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let values = [
            injection.timeScaleMultiplier,
            injection.compressionStrength,
            injection.shockwaveStrength,
            injection.heatInput,
            injection.turbulenceInput,
            injection.radiationInput,
            injection.coolingBias
        ]

        for value in values {
            XCTAssertTrue(value.isFinite, "Expected finite value for influence \(influence)", file: file, line: line)
            XCTAssertGreaterThanOrEqual(value, 0, "Expected non-negative value for influence \(influence)", file: file, line: line)
        }
    }
}
