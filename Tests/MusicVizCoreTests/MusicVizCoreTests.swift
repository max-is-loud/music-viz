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
}
