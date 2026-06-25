import XCTest
@testable import MusicVizCore

final class SimulationParametersTests: XCTestCase {
    func testClampedKeepsValuesInsideStableRanges() {
        let raw = SimulationParameters(
            timeScale: -10,
            audioInfluence: 9,
            particleCountTarget: 99_999_999,
            fieldResolution: 123,
            gravityStrength: -2,
            heatDecay: 2,
            turbulenceStrength: -1,
            starIgnitionThreshold: -50,
            collapseThreshold: 0,
            renderIntensity: 20,
            bloomStrength: -4
        )

        let clamped = raw.clamped()

        XCTAssertEqual(clamped.timeScale, 0.02, accuracy: 0.0001)
        XCTAssertEqual(clamped.audioInfluence, 3.0, accuracy: 0.0001)
        XCTAssertEqual(clamped.particleCountTarget, 2_000_000)
        XCTAssertEqual(clamped.fieldResolution, 128)
        XCTAssertEqual(clamped.gravityStrength, 0.0, accuracy: 0.0001)
        XCTAssertEqual(clamped.heatDecay, 0.999, accuracy: 0.0001)
        XCTAssertEqual(clamped.turbulenceStrength, 0.0, accuracy: 0.0001)
        XCTAssertEqual(clamped.starIgnitionThreshold, 0.01, accuracy: 0.0001)
        XCTAssertEqual(clamped.collapseThreshold, 0.01, accuracy: 0.0001)
        XCTAssertEqual(clamped.renderIntensity, 5.0, accuracy: 0.0001)
        XCTAssertEqual(clamped.bloomStrength, 0.0, accuracy: 0.0001)
    }

    func testClampedNormalizesFieldResolutionForAllPublicInputs() {
        let cases = [
            (input: 0, expected: 128),
            (input: 1, expected: 128),
            (input: 123, expected: 128),
            (input: 192, expected: 256),
            (input: 513, expected: 512),
            (input: 2049, expected: 2048),
            (input: Int.max, expected: 2048)
        ]

        for testCase in cases {
            let clamped = SimulationParameters(fieldResolution: testCase.input).clamped()

            XCTAssertEqual(
                clamped.fieldResolution,
                testCase.expected,
                "fieldResolution \(testCase.input) should normalize to \(testCase.expected)"
            )
        }
    }
}
