import Foundation
import Metal
import MetalKit

@MainActor
public final class CosmicRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let particleState: MetalParticleState
    private let particlePipeline: MTLRenderPipelineState
    private var time: Float = 0
    private var lastDrawTime = Date().timeIntervalSinceReferenceDate

    public init(view: MTKView) throws {
        guard let device = view.device else {
            throw RendererError.missingDevice
        }
        guard let queue = device.makeCommandQueue() else {
            throw RendererError.missingCommandQueue
        }
        let particleState = MetalParticleState(
            device: device,
            particles: ParticleSeed.generate(count: 250_000, seed: 1)
        )
        let library = try ShaderLibrary.makeLibrary(device: device)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "particle_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "particle_fragment")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        let particlePipeline = try device.makeRenderPipelineState(descriptor: descriptor)

        self.device = device
        self.commandQueue = queue
        self.particleState = particleState
        self.particlePipeline = particlePipeline
        super.init()
        view.clearColor = MTLClearColor(red: 0.006, green: 0.008, blue: 0.018, alpha: 1)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        let currentTime = Date().timeIntervalSinceReferenceDate
        time += Float(currentTime - lastDrawTime)
        lastDrawTime = currentTime

        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let pulse = Double((sin(time * 0.5) + 1) * 0.5)
        descriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.006 + pulse * 0.015,
            green: 0.008 + pulse * 0.01,
            blue: 0.018 + pulse * 0.035,
            alpha: 1
        )

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.setRenderPipelineState(particlePipeline)
            encoder.setVertexBuffer(particleState.buffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleState.count)
            encoder.endEncoding()
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

public enum RendererError: LocalizedError {
    case missingDevice
    case missingCommandQueue

    public var errorDescription: String? {
        switch self {
        case .missingDevice:
            return "Metal device is unavailable."
        case .missingCommandQueue:
            return "Metal command queue could not be created."
        }
    }
}
