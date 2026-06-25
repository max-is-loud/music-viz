import Foundation
import Metal
import MetalKit

@MainActor
public final class CosmicRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let appState: AppState
    private let audioSource: AudioInputSource
    private let particleState: MetalParticleState
    private var fieldState: MetalFieldState
    private let particlePipeline: MTLRenderPipelineState
    private let fieldDepositPipeline: MTLRenderPipelineState
    private var decayFieldsPipeline: MTLComputePipelineState
    private let integrateParticlesPipeline: MTLComputePipelineState
    private var needsFieldClear = true
    private var time: Float = 0
    private var lastDrawTime = Date().timeIntervalSinceReferenceDate

    public init(view: MTKView, appState: AppState, audioSource: AudioInputSource) throws {
        guard let device = view.device else {
            throw RendererError.missingDevice
        }
        guard let queue = device.makeCommandQueue() else {
            throw RendererError.missingCommandQueue
        }
        let clampedParameters = SimulationParameters().clamped()
        let particleState = MetalParticleState(
            device: device,
            particles: ParticleSeed.generate(count: clampedParameters.particleCountTarget, seed: 1)
        )
        let fieldState = MetalFieldState(device: device, resolution: clampedParameters.fieldResolution)
        let library = try ShaderLibrary.makeLibrary(device: device)
        guard let decayFunction = library.makeFunction(name: "decay_fields") else {
            throw RendererError.missingShaderFunction("decay_fields")
        }
        let decayFieldsPipeline = try device.makeComputePipelineState(function: decayFunction)
        guard let integrateFunction = library.makeFunction(name: "integrate_particles") else {
            throw RendererError.missingShaderFunction("integrate_particles")
        }
        let integrateParticlesPipeline = try device.makeComputePipelineState(function: integrateFunction)
        guard let fieldDepositVertex = library.makeFunction(name: "field_deposit_vertex") else {
            throw RendererError.missingShaderFunction("field_deposit_vertex")
        }
        guard let fieldDepositFragment = library.makeFunction(name: "field_deposit_fragment") else {
            throw RendererError.missingShaderFunction("field_deposit_fragment")
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "particle_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "particle_fragment")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        Self.configureParticleBlending(descriptor.colorAttachments[0])
        let particlePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let fieldDepositDescriptor = MTLRenderPipelineDescriptor()
        fieldDepositDescriptor.vertexFunction = fieldDepositVertex
        fieldDepositDescriptor.fragmentFunction = fieldDepositFragment
        fieldDepositDescriptor.colorAttachments[0].pixelFormat = fieldState.density.pixelFormat
        fieldDepositDescriptor.colorAttachments[1].pixelFormat = fieldState.heat.pixelFormat
        Self.configureAdditiveBlending(fieldDepositDescriptor.colorAttachments[0])
        Self.configureAdditiveBlending(fieldDepositDescriptor.colorAttachments[1])
        let fieldDepositPipeline = try device.makeRenderPipelineState(descriptor: fieldDepositDescriptor)

        self.device = device
        self.commandQueue = queue
        self.appState = appState
        self.audioSource = audioSource
        self.particleState = particleState
        self.fieldState = fieldState
        self.particlePipeline = particlePipeline
        self.fieldDepositPipeline = fieldDepositPipeline
        self.decayFieldsPipeline = decayFieldsPipeline
        self.integrateParticlesPipeline = integrateParticlesPipeline
        super.init()
        view.clearColor = MTLClearColor(red: 0.006, green: 0.008, blue: 0.018, alpha: 1)
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        let currentTime = Date().timeIntervalSinceReferenceDate
        let controls = RendererSimulationControls(appState: appState)
        if controls.isPaused == false {
            time += Float(currentTime - lastDrawTime)
        }
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

        var params = GPUSimParams.make(
            controls: controls,
            audioFeatures: audioSource.latestFeatures,
            particleCount: particleState.count,
            fieldResolution: fieldState.resolution,
            deltaTime: 1.0 / 120.0
        )

        if needsFieldClear {
            needsFieldClear = !fieldState.encodeClear(on: commandBuffer)
        }

        if controls.isPaused == false, let compute = commandBuffer.makeComputeCommandEncoder() {
            compute.setComputePipelineState(decayFieldsPipeline)
            compute.setTexture(fieldState.density, index: 0)
            compute.setTexture(fieldState.heat, index: 1)
            compute.setBytes(&params, length: MemoryLayout<GPUSimParams>.stride, index: 0)
            let threads = MTLSize(width: 16, height: 16, depth: 1)
            let groups = MTLSize(
                width: (fieldState.resolution + 15) / 16,
                height: (fieldState.resolution + 15) / 16,
                depth: 1
            )
            compute.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
            compute.endEncoding()
        }

        if controls.isPaused == false,
           particleState.count > 0,
           let compute = commandBuffer.makeComputeCommandEncoder() {
            compute.setComputePipelineState(integrateParticlesPipeline)
            compute.setBuffer(particleState.buffer, offset: 0, index: 0)
            compute.setBytes(&params, length: MemoryLayout<GPUSimParams>.stride, index: 1)
            compute.setTexture(fieldState.density, index: 0)
            let threads = MTLSize(width: 256, height: 1, depth: 1)
            let groups = MTLSize(width: (particleState.count + 255) / 256, height: 1, depth: 1)
            compute.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
            compute.endEncoding()
        }

        if controls.isPaused == false,
           particleState.count > 0,
           let encoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: fieldDepositRenderPassDescriptor()
        ) {
            encoder.setRenderPipelineState(fieldDepositPipeline)
            encoder.setVertexBuffer(particleState.buffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleState.count)
            encoder.endEncoding()
        }

        if particleState.count > 0, let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.setRenderPipelineState(particlePipeline)
            encoder.setVertexBuffer(particleState.buffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleState.count)
            encoder.endEncoding()
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func fieldDepositRenderPassDescriptor() -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        configureFieldDepositAttachment(descriptor.colorAttachments[0], texture: fieldState.density)
        configureFieldDepositAttachment(descriptor.colorAttachments[1], texture: fieldState.heat)
        return descriptor
    }

    private func configureFieldDepositAttachment(
        _ attachment: MTLRenderPassColorAttachmentDescriptor,
        texture: MTLTexture
    ) {
        attachment.texture = texture
        attachment.loadAction = .load
        attachment.storeAction = .store
    }

    private static func configureParticleBlending(
        _ attachment: MTLRenderPipelineColorAttachmentDescriptor
    ) {
        attachment.isBlendingEnabled = true
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .one
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
    }

    private static func configureAdditiveBlending(
        _ attachment: MTLRenderPipelineColorAttachmentDescriptor
    ) {
        attachment.isBlendingEnabled = true
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = .one
        attachment.destinationRGBBlendFactor = .one
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .one
    }
}

struct RendererSimulationControls: Equatable {
    var parameters: SimulationParameters
    var isPaused: Bool

    @MainActor
    init(appState: AppState) {
        parameters = appState.parameters.clamped()
        isPaused = appState.isPaused
    }
}

public enum RendererError: LocalizedError {
    case missingDevice
    case missingCommandQueue
    case missingShaderFunction(String)

    public var errorDescription: String? {
        switch self {
        case .missingDevice:
            return "Metal device is unavailable."
        case .missingCommandQueue:
            return "Metal command queue could not be created."
        case .missingShaderFunction(let name):
            return "Metal shader function '\(name)' was not found."
        }
    }
}

struct GPUSimParams {
    var deltaTime: Float
    var timeScale: Float
    var audioInfluence: Float
    var gravityStrength: Float
    var heatDecay: Float
    var turbulenceStrength: Float
    var starIgnitionThreshold: Float
    var collapseThreshold: Float
    var compressionStrength: Float
    var shockwaveStrength: Float
    var heatInput: Float
    var turbulenceInput: Float
    var radiationInput: Float
    var coolingBias: Float
    var particleCount: UInt32
    var fieldResolution: UInt32

    static func make(
        controls: RendererSimulationControls,
        audioFeatures: AudioFeatures,
        particleCount: Int,
        fieldResolution: Int,
        deltaTime: Float
    ) -> GPUSimParams {
        let injection = controls.isPaused
            ? AudioInjection(
                timeScaleMultiplier: 0,
                compressionStrength: 0,
                shockwaveStrength: 0,
                heatInput: 0,
                turbulenceInput: 0,
                radiationInput: 0,
                coolingBias: 0
            )
            : AudioForceMapper.map(audioFeatures, parameters: controls.parameters)

        return GPUSimParams(
            deltaTime: controls.isPaused ? 0 : deltaTime,
            timeScale: controls.isPaused ? 0 : controls.parameters.timeScale * injection.timeScaleMultiplier,
            audioInfluence: controls.parameters.audioInfluence,
            gravityStrength: controls.parameters.gravityStrength,
            heatDecay: controls.parameters.heatDecay,
            turbulenceStrength: controls.parameters.turbulenceStrength,
            starIgnitionThreshold: controls.parameters.starIgnitionThreshold,
            collapseThreshold: controls.parameters.collapseThreshold,
            compressionStrength: injection.compressionStrength,
            shockwaveStrength: injection.shockwaveStrength,
            heatInput: injection.heatInput,
            turbulenceInput: injection.turbulenceInput,
            radiationInput: injection.radiationInput,
            coolingBias: injection.coolingBias,
            particleCount: UInt32(max(0, particleCount)),
            fieldResolution: UInt32(max(1, fieldResolution))
        )
    }
}
