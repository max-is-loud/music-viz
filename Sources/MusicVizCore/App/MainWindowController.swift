import AppKit

@MainActor
public final class MainWindowController: NSWindowController {
    private let appState: AppState
    private let audioSource: AudioInputSource

    public convenience init(appState: AppState) {
        let audioSource = AudioSourceFactory.makeDefaultSource()
        appState.statusText = audioSource.statusText
        self.init(appState: appState, audioSource: audioSource)
    }

    public convenience init(appState: AppState, audioSource: AudioInputSource) {
        self.init(appState: appState, audioSource: audioSource) {
            try MetalCanvasView(appState: appState, audioSource: audioSource)
        }
    }

    init(
        appState: AppState,
        audioSource: AudioInputSource = SyntheticAudioSource(),
        contentViewFactory: () throws -> NSView
    ) {
        self.appState = appState
        self.audioSource = audioSource
        let window = NSWindow(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1600, height: 1000),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MusicViz"
        do {
            window.contentView = try contentViewFactory()
        } catch {
            appState.statusText = error.localizedDescription
            window.contentView = Self.makeFallbackView(statusText: appState.statusText)
        }
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

    private static func makeFallbackView(statusText: String) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(
            red: 0.006,
            green: 0.008,
            blue: 0.018,
            alpha: 1
        ).cgColor

        let label = NSTextField(labelWithString: statusText)
        label.alignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }
}
