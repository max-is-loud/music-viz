import AppKit

@MainActor
public final class MainWindowController: NSWindowController {
    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
        let label = NSTextField(labelWithString: appState.statusText)
        label.alignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(
            red: 0.006,
            green: 0.008,
            blue: 0.018,
            alpha: 1
        ).cgColor
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let window = NSWindow(
            contentRect: container.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MusicViz"
        window.contentView = container
        window.collectionBehavior = [.fullScreenPrimary, .canJoinAllSpaces]
        window.titlebarAppearsTransparent = true
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
