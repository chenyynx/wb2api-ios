import XCTest
@testable import WB2API

/// 今日消耗按东八区自然日聚合，不能把昨天的 23 点算进今天。
final class UsageTodayTests: XCTestCase {
    private func decode(_ raw: String) throws -> UsageSnapshot {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(UsageSnapshot.self, from: Data(raw.utf8))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testSumsOnlyToday() throws {
        let snapshot = try decode("""
        {"series":[
          {"t":"2026-10-26T23","requests":9,"total_tokens":900,"credits":9.0},
          {"t":"2026-10-27T00","requests":2,"total_tokens":100,"credits":1.5},
          {"t":"2026-10-27T01","requests":3,"total_tokens":200,"credits":2.5},
          {"t":"2026-10-27T02","requests":1,"tokens":50,"credits":0.5}
        ]}
        """)

        let today = try XCTUnwrap(UsageToday.totals(in: snapshot, now: date(2026, 10, 27, 12)))
        XCTAssertEqual(today.tokens, 350)
        XCTAssertEqual(today.requests, 6)
        XCTAssertEqual(today.credits, 4.5, accuracy: 0.0001)
        XCTAssertEqual(today.dayKey, "2026-10-27")
        XCTAssertEqual(today.dayLabel, "10-27")
    }

    func testMidnightBoundaryUsesCalendarDay() throws {
        let snapshot = try decode("""
        {"series":[
          {"t":"2026-10-26T23","requests":9,"total_tokens":900,"credits":9.0},
          {"t":"2026-10-27T00","requests":2,"total_tokens":100,"credits":1.5}
        ]}
        """)

        let today = try XCTUnwrap(UsageToday.totals(in: snapshot, now: date(2026, 10, 27, 0)))
        XCTAssertEqual(today.tokens, 100)
        XCTAssertEqual(today.requests, 2)
        XCTAssertEqual(today.credits, 1.5, accuracy: 0.0001)
    }

    func testNoTodayBucketReturnsNil() throws {
        let snapshot = try decode("""
        {"series":[{"t":"2026-10-26T23","requests":9,"total_tokens":900}]}
        """)
        XCTAssertNil(UsageToday.totals(in: snapshot, now: date(2026, 10, 27, 12)))
    }

    func testEmptySeriesReturnsNil() throws {
        let snapshot = try decode(#"{"series":[]}"#)
        XCTAssertNil(UsageToday.totals(in: snapshot, now: date(2026, 10, 27, 12)))
    }
}
