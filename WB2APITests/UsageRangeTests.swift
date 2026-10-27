import XCTest
@testable import WB2API

/// 今日/昨日必须按东八区自然日算，且不能被当成滚动小时窗口。
final class UsageRangeTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testTodayWindowStartsAtMidnight() throws {
        let now = date(2026, 10, 27, 15, 30)
        let window = try XCTUnwrap(UsageRange.today.window(now: now))
        XCTAssertEqual(window.from, date(2026, 10, 27, 0))
        XCTAssertEqual(window.to, now)
        XCTAssertNil(UsageRange.today.hours)
    }

    func testYesterdayWindowEndsOneSecondBeforeToday() throws {
        let now = date(2026, 10, 27, 15, 30)
        let window = try XCTUnwrap(UsageRange.yesterday.window(now: now))
        XCTAssertEqual(window.from, date(2026, 10, 26, 0))
        XCTAssertEqual(window.to.timeIntervalSince(window.from), 86_400 - 1)
        XCTAssertNil(UsageRange.yesterday.hours)
    }

    func testRollingRangesHaveNoExplicitWindow() {
        for range in [UsageRange.days3, .days7, .days30, .all] {
            XCTAssertNil(range.window())
            XCTAssertNotNil(range.hours)
        }
        XCTAssertEqual(UsageRange.days3.hours, 72)
        XCTAssertEqual(UsageRange.days7.hours, 168)
        XCTAssertEqual(UsageRange.days30.hours, 720)
        XCTAssertEqual(UsageRange.all.hours, 1_440)
    }

    func testSingleDayFlags() {
        XCTAssertTrue(UsageRange.today.isSingleDay)
        XCTAssertTrue(UsageRange.yesterday.isSingleDay)
        XCTAssertFalse(UsageRange.days3.isSingleDay)
        XCTAssertFalse(UsageRange.all.isSingleDay)
    }

    func testAllCasesOrderStartsWithDays() {
        XCTAssertEqual(UsageRange.allCases.map(\.title),
                       ["今日", "昨日", "3 天", "7 天", "30 天", "总计"])
    }
}
