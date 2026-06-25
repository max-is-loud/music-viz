import Metal
import XCTest
@testable import MusicVizCore

final class ParticleSeedTests: XCTestCase {
    func testSeededParticlesAreDeterministic() {
        let a = ParticleSeed.generate(count: 4, seed: 42)
        let b = ParticleSeed.generate(count: 4, seed: 42)
        XCTAssertEqual(a, b)
    }

    func testSeededParticlesStayInsideNormalizedSpace() {
        let particles = ParticleSeed.generate(count: 256, seed: 9)
        XCTAssertEqual(particles.count, 256)
        for particle in particles {
            XCTAssertGreaterThanOrEqual(particle.x, -1)
            XCTAssertLessThanOrEqual(particle.x, 1)
            XCTAssertGreaterThanOrEqual(particle.y, -1)
            XCTAssertLessThanOrEqual(particle.y, 1)
            XCTAssertGreaterThan(particle.mass, 0)
            XCTAssertGreaterThanOrEqual(particle.temperature, 0)
        }
    }

    func testZeroCountSeedGeneratesNoParticles() {
        XCTAssertEqual(ParticleSeed.generate(count: 0, seed: 123), [])
    }

    func testSeedParticleLayoutMatchesShaderContract() {
        XCTAssertEqual(MemoryLayout<SeedParticle>.size, 32)
        XCTAssertEqual(MemoryLayout<SeedParticle>.stride, 32)
        XCTAssertEqual(MemoryLayout<SeedParticle>.alignment, 4)
        XCTAssertEqual(MemoryLayout<SeedParticle>.offset(of: \.x), 0 as Int?)
        XCTAssertEqual(MemoryLayout<SeedParticle>.offset(of: \.y), 4 as Int?)
        XCTAssertEqual(MemoryLayout<SeedParticle>.offset(of: \.vx), 8 as Int?)
        XCTAssertEqual(MemoryLayout<SeedParticle>.offset(of: \.vy), 12 as Int?)
        XCTAssertEqual(MemoryLayout<SeedParticle>.offset(of: \.mass), 16 as Int?)
        XCTAssertEqual(MemoryLayout<SeedParticle>.offset(of: \.temperature), 20 as Int?)
        XCTAssertEqual(MemoryLayout<SeedParticle>.offset(of: \.age), 24 as Int?)
        XCTAssertEqual(MemoryLayout<SeedParticle>.offset(of: \.kind), 28 as Int?)
    }

    func testEmptyMetalParticleStateCanBeConstructedSafely() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is unavailable.")
        }

        let state = MetalParticleState(device: device, particles: [])

        XCTAssertEqual(state.count, 0)
        XCTAssertEqual(state.buffer.length, MemoryLayout<SeedParticle>.stride)
    }
}
