import XCTest

final class LabPanelViewTests: XCTestCase {
    func testLabPanelDoesNotExposeUnwiredRenderControls() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MusicVizCore/Lab/LabPanelView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("slider(\"Render\""))
        XCTAssertFalse(source.contains("slider(\"Bloom\""))
    }
}
