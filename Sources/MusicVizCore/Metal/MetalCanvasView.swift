import AppKit
import Metal
import MetalKit

@MainActor
public final class MetalCanvasView: MTKView {
    private var cosmicRenderer: CosmicRenderer?

    public init(appState: AppState) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("MusicViz requires an Apple Silicon Mac with Metal support.")
        }
        super.init(frame: .zero, device: device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = false
        preferredFramesPerSecond = 120
        enableSetNeedsDisplay = false
        isPaused = false
        autoResizeDrawable = true

        do {
            let renderer = try CosmicRenderer(view: self)
            self.cosmicRenderer = renderer
            delegate = renderer
        } catch {
            appState.statusText = error.localizedDescription
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}
