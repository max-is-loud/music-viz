import AppKit

@MainActor
public enum AppLauncher {
    private static var bootstrapDelegate: BootstrapDelegate?

    static func installBootstrapDelegate(on app: NSApplication) {
        let delegate = BootstrapDelegate()
        bootstrapDelegate = delegate
        app.delegate = delegate
    }

    public static func main() {
        let app = NSApplication.shared
        installBootstrapDelegate(on: app)
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

@MainActor
private final class BootstrapDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState()
        let controller = MainWindowController(appState: state)
        self.windowController = controller
        controller.showWindow(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
