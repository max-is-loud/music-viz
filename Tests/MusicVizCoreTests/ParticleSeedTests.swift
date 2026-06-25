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
}
