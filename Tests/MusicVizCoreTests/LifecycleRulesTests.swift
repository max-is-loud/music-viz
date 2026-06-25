import XCTest
@testable import MusicVizCore

final class LifecycleRulesTests: XCTestCase {
    func testDenseHotDustBecomesProtostar() {
        let input = LifecycleSample(kind: .dust, mass: 2.0, temperature: 0.9, age: 4, localDensity: 0.95)
        XCTAssertEqual(LifecycleRules.nextKind(input, parameters: .init()), .protostar)
    }

    func testOldHotProtostarBecomesStar() {
        let input = LifecycleSample(kind: .protostar, mass: 2.5, temperature: 1.1, age: 12, localDensity: 1.0)
        XCTAssertEqual(LifecycleRules.nextKind(input, parameters: .init()), .star)
    }

    func testVeryHotMassiveStarBecomesUnstable() {
        let input = LifecycleSample(kind: .star, mass: 3.2, temperature: 2.3, age: 55, localDensity: 1.4)
        XCTAssertEqual(LifecycleRules.nextKind(input, parameters: .init()), .unstableStar)
    }

    func testUnstableStarCollapsesToRemnant() {
        let input = LifecycleSample(kind: .unstableStar, mass: 3.6, temperature: 2.6, age: 70, localDensity: 1.7)
        XCTAssertEqual(LifecycleRules.nextKind(input, parameters: .init()), .remnant)
    }
}
