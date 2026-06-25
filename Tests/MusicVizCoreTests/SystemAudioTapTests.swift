import CoreAudio
import XCTest
@testable import MusicVizCore

final class SystemAudioTapTests: XCTestCase {
    func testAggregateDescriptionDoesNotAutoStartTap() {
        let description = SystemAudioTapConfiguration.aggregateDescription(tapUID: "tap-id" as CFString)

        XCTAssertEqual(description[kAudioAggregateDeviceTapAutoStartKey] as? Bool, false)
        XCTAssertEqual(description[kAudioAggregateDeviceIsPrivateKey] as? Bool, true)

        let tapList = description[kAudioAggregateDeviceTapListKey] as? [[String: Any]]
        XCTAssertEqual(tapList?.count, 1)
        XCTAssertEqual(tapList?.first?[kAudioSubTapUIDKey] as? String, "tap-id")
    }

    func testControlQueueSyncRunsInlineWhenAlreadyOnQueue() {
        let queue = SystemAudioTapControlQueue(label: "MusicVizCore.SystemAudioTapTests")
        let expectation = expectation(description: "nested sync completed")

        queue.async {
            queue.sync {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func testDispatchQueueReportsWhenAlreadyOnQueue() {
        let queue = SystemAudioTapDispatchQueue(label: "MusicVizCore.SystemAudioTapTests.Identity")
        let expectation = expectation(description: "queue identity checked")

        XCTAssertFalse(queue.isCurrent)

        queue.async {
            XCTAssertTrue(queue.isCurrent)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func testSampleHandoffCopiesBoundedFiniteSamples() {
        let handoff = AudioSampleHandoff(capacity: 4)

        let acceptedCount = handoff.copyFromCallback([
            Float(0.1),
            .nan,
            Float.greatestFiniteMagnitude,
            -Float.greatestFiniteMagnitude,
            Float(0.5)
        ])
        let snapshot = handoff.drainForAnalysis()

        XCTAssertEqual(acceptedCount, 4)
        XCTAssertEqual(snapshot, [0.1, 0, 16, -16])
    }
}
