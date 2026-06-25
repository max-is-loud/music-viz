import Metal

public final class MetalParticleState {
    public let count: Int
    public let buffer: MTLBuffer

    public init(device: MTLDevice, particles: [SeedParticle]) {
        self.count = particles.count
        let particleStride = MemoryLayout<SeedParticle>.stride
        let buffer: MTLBuffer?
        if particles.isEmpty {
            buffer = device.makeBuffer(length: particleStride, options: [.storageModeShared])
        } else {
            buffer = device.makeBuffer(
                bytes: particles,
                length: particles.count * particleStride,
                options: [.storageModeShared]
            )
        }
        guard let buffer = buffer else {
            fatalError("Unable to create particle buffer.")
        }
        self.buffer = buffer
    }
}
