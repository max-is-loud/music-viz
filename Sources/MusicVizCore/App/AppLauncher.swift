import AppKit

@MainActor
public enum AppLauncher {
    public static func main() {
        let app = NSApplication.shared
        let delegate = BootstrapDelegate()
        app.delegate = delegate
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
