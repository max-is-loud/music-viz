import XCTest
@testable import MusicVizCore

@MainActor
final class AppStateTests: XCTestCase {
    func testResetToDefaultsRestoresSimulationAndAmbientStatus() {
        let appState = AppState()
        appState.isLabVisible = true
        appState.isPaused = true
        appState.statusText = "Manual override"
        appState.debugOverlay = "Particles"
        appState.parameters = SimulationParameters(
            timeScale: 4,
            audioInfluence: 2,
            particleCountTarget: 10_000,
            fieldResolution: 256,
            gravityStrength: 3,
            heatDecay: 0.9,
            turbulenceStrength: 2,
            starIgnitionThreshold: 1.5,
            collapseThreshold: 2,
            renderIntensity: 4,
            bloomStrength: 2
        )

        appState.resetToDefaults()

        XCTAssertTrue(appState.isLabVisible)
        XCTAssertTrue(appState.isPaused)
        XCTAssertEqual(appState.parameters, SimulationParameters())
        XCTAssertEqual(appState.debugOverlay, "None")
        XCTAssertEqual(appState.statusText, "Cosmic simmer")
    }
}
