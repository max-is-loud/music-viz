@testable import MusicVizCore
import AppKit
import XCTest

@MainActor
final class MainWindowControllerTests: XCTestCase {
    func testShowsVisibleStatusFallbackWhenMetalContentCreationFails() throws {
        let appState = AppState()
        let audioSource = InertAudioSource()

        let controller = MainWindowController(
            appState: appState,
            audioSource: audioSource,
            contentViewFactory: { throw RendererError.missingDevice }
        )

        XCTAssertEqual(appState.statusText, "Metal device is unavailable.")

        let contentView: NSView = try XCTUnwrap(controller.window?.contentView)
        let label: NSTextField = try XCTUnwrap(
            contentView.subviews.compactMap { $0 as? NSTextField }.first
        )
        XCTAssertEqual(label.stringValue, "Metal device is unavailable.")
        XCTAssertEqual(label.alignment, NSTextAlignment.center)
        XCTAssertEqual(label.textColor, NSColor.white)
        XCTAssertTrue(contentView.wantsLayer)
        XCTAssertFalse(audioSource.didStart)
    }

    func testMainWindowControllerDoesNotCreateDefaultAudioSource() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MusicVizCore/App/MainWindowController.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("AudioSourceFactory.makeDefaultSource()"))
    }
}

private final class InertAudioSource: AudioInputSource {
    private(set) var didStart = false

    var latestFeatures: AudioFeatures { .silence }
    var statusText: String { "Inert audio" }
    var isUsingFallback: Bool { true }
    func start() { didStart = true }
    func stop() {}
}
