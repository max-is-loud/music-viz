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
}
