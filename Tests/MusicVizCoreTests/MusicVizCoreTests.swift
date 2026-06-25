@testable import MusicVizCore
import AppKit
import XCTest

@MainActor
final class AppLauncherTests: XCTestCase {
    func testInstallBootstrapDelegateRetainsApplicationDelegate() {
        let app = NSApplication.shared

        AppLauncher.installBootstrapDelegate(on: app)

        XCTAssertNotNil(app.delegate)
    }

    func testExecutableDeclaresAppleSiliconOnlyGuard() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MusicVizApp/main.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("#if !arch(arm64)"))
        XCTAssertTrue(source.contains("#error(\"MusicViz currently supports Apple Silicon only.\")"))
    }
}
