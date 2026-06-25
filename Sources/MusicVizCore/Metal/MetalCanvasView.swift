import AppKit
import Metal
import MetalKit

@MainActor
public final class MetalCanvasView: MTKView {
    private var cosmicRenderer: CosmicRenderer?

    public init(appState: AppState) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.missingDevice
        }
        super.init(frame: .zero, device: device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        preferredFramesPerSecond = 120
        enableSetNeedsDisplay = false
        isPaused = false
        autoResizeDrawable = true

        let renderer = try CosmicRenderer(view: self)
        self.cosmicRenderer = renderer
        delegate = renderer
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }
}
