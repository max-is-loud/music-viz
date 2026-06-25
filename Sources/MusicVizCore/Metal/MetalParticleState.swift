import Metal

public final class MetalParticleState {
    public let count: Int
    public let buffer: MTLBuffer

    public init(device: MTLDevice, particles: [SeedParticle]) {
        self.count = particles.count
        let byteCount = max(1, particles.count) * MemoryLayout<SeedParticle>.stride
        guard let buffer = device.makeBuffer(bytes: particles, length: byteCount, options: [.storageModeShared]) else {
            fatalError("Unable to create particle buffer.")
        }
        self.buffer = buffer
    }
}
