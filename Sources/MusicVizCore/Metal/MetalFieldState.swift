import Metal

public final class MetalFieldState {
    public let resolution: Int
    public let density: MTLTexture
    public let heat: MTLTexture

    public init(device: MTLDevice, resolution: Int) {
        self.resolution = resolution
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: resolution,
            height: resolution,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .private

        guard let density = device.makeTexture(descriptor: descriptor),
              let heat = device.makeTexture(descriptor: descriptor) else {
            fatalError("Unable to allocate field textures.")
        }
        self.density = density
        self.heat = heat
    }

    @discardableResult
    func encodeClear(on commandBuffer: MTLCommandBuffer) -> Bool {
        let descriptor = MTLRenderPassDescriptor()
        configureClearAttachment(descriptor.colorAttachments[0], texture: density)
        configureClearAttachment(descriptor.colorAttachments[1], texture: heat)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return false
        }
        encoder.endEncoding()
        return true
    }

    private func configureClearAttachment(
        _ attachment: MTLRenderPassColorAttachmentDescriptor,
        texture: MTLTexture
    ) {
        attachment.texture = texture
        attachment.loadAction = .clear
        attachment.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        attachment.storeAction = .store
    }
}
