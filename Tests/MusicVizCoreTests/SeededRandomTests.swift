import XCTest
@testable import MusicVizCore

final class SeededRandomTests: XCTestCase {
    func testSameSeedProducesSameSequence() {
        var first = SeededRandom(seed: 42)
        var second = SeededRandom(seed: 42)

        for _ in 0..<8 {
            XCTAssertEqual(first.nextUInt64(), second.nextUInt64())
        }
    }

    func testGeneratedFloatsStayInExpectedRanges() {
        var random = SeededRandom(seed: 7)

        for _ in 0..<100 {
            let unsigned = random.nextFloat()
            XCTAssertGreaterThanOrEqual(unsigned, 0)
            XCTAssertLessThan(unsigned, 1)

            let signed = random.nextSignedFloat()
            XCTAssertGreaterThanOrEqual(signed, -1)
            XCTAssertLessThan(signed, 1)
        }
    }
}
