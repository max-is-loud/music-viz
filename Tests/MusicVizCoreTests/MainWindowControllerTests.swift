@testable import MusicVizCore
import AppKit
import XCTest

@MainActor
final class MainWindowControllerTests: XCTestCase {
    func testShowsVisibleStatusFallbackWhenMetalContentCreationFails() throws {
        let appState = AppState()

        let controller = MainWindowController(
            appState: appState,
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
    }
}
