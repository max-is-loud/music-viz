@testable import MusicVizCore
import XCTest

@MainActor
final class RendererSimulationControlTests: XCTestCase {
    func testGpuParametersUseAppStateParametersAndPauseState() {
        let appState = AppState()
        appState.parameters = SimulationParameters(
            timeScale: 4,
            audioInfluence: 0.5,
            particleCountTarget: 99_000,
            fieldResolution: 256,
            gravityStrength: 2.5,
            heatDecay: 0.91,
            turbulenceStrength: 1.25,
            starIgnitionThreshold: 1.4,
            collapseThreshold: 2.8,
            renderIntensity: 1,
            bloomStrength: 1
        )
        let features = AudioFeatures(
            overallEnergy: 0.4,
            bass: 0.25,
            lowMid: 0.2,
            mid: 0.1,
            high: 0.05,
            transient: 0.3,
            brightness: 0.15,
            sustainedIntensity: 0.5,
            isSilent: false
        )

        let running = GPUSimParams.make(
            controls: RendererSimulationControls(appState: appState),
            audioFeatures: features,
            particleCount: 42,
            fieldResolution: 256,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertEqual(running.deltaTime, 1.0 / 60.0, accuracy: 0.0001)
        XCTAssertEqual(running.timeScale, 5.8, accuracy: 0.0001)
        XCTAssertEqual(running.audioInfluence, 0.5, accuracy: 0.0001)
        XCTAssertEqual(running.gravityStrength, 2.5, accuracy: 0.0001)
        XCTAssertEqual(running.heatDecay, 0.91, accuracy: 0.0001)
        XCTAssertEqual(running.turbulenceStrength, 1.25, accuracy: 0.0001)
        XCTAssertEqual(running.starIgnitionThreshold, 1.4, accuracy: 0.0001)
        XCTAssertEqual(running.collapseThreshold, 2.8, accuracy: 0.0001)
        XCTAssertEqual(running.particleCount, 42)
        XCTAssertEqual(running.fieldResolution, 256)

        appState.isPaused = true
        let paused = GPUSimParams.make(
            controls: RendererSimulationControls(appState: appState),
            audioFeatures: features,
            particleCount: 42,
            fieldResolution: 256,
            deltaTime: 1.0 / 60.0
        )

        XCTAssertEqual(paused.deltaTime, 0)
        XCTAssertEqual(paused.timeScale, 0)
        XCTAssertEqual(paused.compressionStrength, 0)
        XCTAssertEqual(paused.shockwaveStrength, 0)
        XCTAssertEqual(paused.heatInput, 0)
        XCTAssertEqual(paused.turbulenceInput, 0)
        XCTAssertEqual(paused.radiationInput, 0)
    }
}
