import AppKit
import SwiftUI

@MainActor
public final class MainWindowController: NSWindowController {
    private let appState: AppState
    private let audioSource: AudioInputSource
    private var keyMonitor: LocalKeyMonitor?

    public convenience init(appState: AppState, audioSource: AudioInputSource) {
        self.init(appState: appState, audioSource: audioSource) {
            NSHostingView(rootView: AppRootOverlay(appState: appState, audioSource: audioSource))
        }
    }

    init(
        appState: AppState,
        audioSource: AudioInputSource,
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

        keyMonitor = LocalKeyMonitor(appState: appState)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    fileprivate static func makeFallbackView(statusText: String) -> NSView {
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

private final class LocalKeyMonitor {
    private let monitor: Any?

    @MainActor
    init(appState: AppState) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            if event.charactersIgnoringModifiers == "l" {
                appState?.isLabVisible.toggle()
                return nil
            }
            if event.charactersIgnoringModifiers == " " {
                appState?.isPaused.toggle()
                return nil
            }
            return event
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

private struct AppRootOverlay: View {
    @ObservedObject var appState: AppState
    let audioSource: AudioInputSource

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RootView(appState: appState, audioSource: audioSource)
                .ignoresSafeArea()

            if appState.isLabVisible {
                LabPanelView(appState: appState)
                    .padding(20)
            }
        }
    }
}

private struct RootView: NSViewControllerRepresentable {
    let appState: AppState
    let audioSource: AudioInputSource

    func makeNSViewController(context: Context) -> NSViewController {
        let viewController = NSViewController()
        do {
            viewController.view = try MetalCanvasView(appState: appState, audioSource: audioSource)
        } catch {
            appState.statusText = error.localizedDescription
            viewController.view = MainWindowController.makeFallbackView(statusText: appState.statusText)
        }
        return viewController
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}
