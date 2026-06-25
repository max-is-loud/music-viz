import AppKit

@MainActor
public final class MainWindowController: NSWindowController {
    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
        let content = MetalCanvasView(appState: appState)
        let window = NSWindow(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1600, height: 1000),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MusicViz"
        window.contentView = content
        window.collectionBehavior = [.fullScreenPrimary, .canJoinAllSpaces]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }
}
