import XCTest
@testable import WB2API

/// 队列状态：完成之后不能再把总数当成「排队中」。
final class TaskQueueDisplayTests: XCTestCase {
    private func queue(
        _ statuses: [String],
        running: Bool = false,
        total: Int? = nil
    ) -> TaskQueue {
        TaskQueue(
            conc: 1,
            items: statuses.map { .object(["status": .string($0)]) },
            running: running,
            seq: 1,
            started: true,
            startedAt: nil,
            total: total ?? statuses.count
        )
    }

    func testFinishedQueueShowsProcessedNotQueued() {
        let q = queue(Array(repeating: "done", count: 8) + ["skipped"], total: 9)
        XCTAssertEqual(q.processedCount, 9)
        XCTAssertEqual(q.remainingCount, 0)
        XCTAssertTrue(q.isFinished)
        XCTAssertEqual(q.stateText, "已完成")
    }

    func testRunningQueueCountsOnlyRemainingItems() {
        let q = queue(Array(repeating: "done", count: 8) + ["running"], running: true, total: 9)
        XCTAssertEqual(q.processedCount, 8)
        XCTAssertEqual(q.remainingCount, 1)
        XCTAssertFalse(q.isFinished)
        XCTAssertEqual(q.stateText, "运行中")
    }

    func testFailureIsReportedAsFailedState() {
        let q = queue(Array(repeating: "done", count: 3) + ["failed"], total: 4)
        XCTAssertEqual(q.failedCount, 1)
        XCTAssertEqual(q.remainingCount, 0)
        XCTAssertTrue(q.isFinished)
        XCTAssertEqual(q.stateText, "有失败")
    }

    func testTruncatedItemsFallBackToTotal() {
        let q = queue(["done", "done"], total: 9)
        XCTAssertEqual(q.processedCount, 2)
        XCTAssertEqual(q.remainingCount, 7)
        XCTAssertFalse(q.isFinished)
        XCTAssertEqual(q.stateText, "空闲")
    }

    func testEmptyQueue() {
        let q = queue([], total: 0)
        XCTAssertEqual(q.remainingCount, 0)
        XCTAssertFalse(q.isFinished)
        XCTAssertEqual(q.stateText, "空闲")
    }
}
