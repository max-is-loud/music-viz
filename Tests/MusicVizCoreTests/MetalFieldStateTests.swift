import Metal
import XCTest
@testable import MusicVizCore

final class MetalFieldStateTests: XCTestCase {
    func testEncodeClearResetsDensityAndHeatTexturesToZero() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw XCTSkip("Metal device is unavailable.")
        }
        let fieldState = MetalFieldState(device: device, resolution: 4)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return XCTFail("Unable to create command buffer.")
        }

        try encodeNonzeroClear(for: fieldState, on: commandBuffer)
        let nonzeroDensityReadback = try makeReadbackBuffer(for: fieldState.density, on: commandBuffer)
        let nonzeroHeatReadback = try makeReadbackBuffer(for: fieldState.heat, on: commandBuffer)
        fieldState.encodeClear(on: commandBuffer)
        let densityReadback = try makeReadbackBuffer(for: fieldState.density, on: commandBuffer)
        let heatReadback = try makeReadbackBuffer(for: fieldState.heat, on: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        XCTAssertNil(commandBuffer.error)
        XCTAssertFalse(allBytesAreZero(in: nonzeroDensityReadback))
        XCTAssertFalse(allBytesAreZero(in: nonzeroHeatReadback))
        XCTAssertTrue(allBytesAreZero(in: densityReadback))
        XCTAssertTrue(allBytesAreZero(in: heatReadback))
    }

    private func encodeNonzeroClear(
        for fieldState: MetalFieldState,
        on commandBuffer: MTLCommandBuffer
    ) throws {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = fieldState.density
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0.5, blue: 0.25, alpha: 1)
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[1].texture = fieldState.heat
        descriptor.colorAttachments[1].loadAction = .clear
        descriptor.colorAttachments[1].clearColor = MTLClearColor(red: 0.125, green: 0.25, blue: 0.5, alpha: 1)
        descriptor.colorAttachments[1].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            throw XCTSkip("Unable to create render encoder.")
        }
        encoder.endEncoding()
    }

    private func makeReadbackBuffer(
        for texture: MTLTexture,
        on commandBuffer: MTLCommandBuffer
    ) throws -> MTLBuffer {
        let bytesPerPixel = 8
        let bytesPerRow = texture.width * bytesPerPixel
        let length = bytesPerRow * texture.height
        let buffer = try XCTUnwrap(
            texture.device.makeBuffer(length: length, options: [.storageModeShared])
        )
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw XCTSkip("Unable to create blit encoder.")
        }
        blit.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: region.origin,
            sourceSize: region.size,
            to: buffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: length
        )
        blit.endEncoding()
        return buffer
    }

    private func allBytesAreZero(in buffer: MTLBuffer) -> Bool {
        let bytes = buffer.contents().bindMemory(to: UInt8.self, capacity: buffer.length)
        for index in 0..<buffer.length where bytes[index] != 0 {
            return false
        }
        return true
    }
}
