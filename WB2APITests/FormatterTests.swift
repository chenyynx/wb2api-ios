import XCTest
@testable import WB2API

final class FormatterTests: XCTestCase {
    func testCreditsFormatting() {
        XCTAssertEqual(Fmt.credits(2549), "2,549")
        XCTAssertEqual(Fmt.credits(21_722), "21.7k")
        XCTAssertEqual(Fmt.credits(nil), "—")
        XCTAssertEqual(Fmt.credits(0), "0")
    }

    func testCompactFormatting() {
        XCTAssertEqual(Fmt.compact(3_400), "3.4k")
        XCTAssertEqual(Fmt.compact(1_200_000), "1.2M")
        XCTAssertEqual(Fmt.compact(999), "999")
        XCTAssertEqual(Fmt.compact(nil), "—")
    }

    func testPercentFormatting() {
        XCTAssertEqual(Fmt.percent(0.992), "99.2%")
        XCTAssertEqual(Fmt.percent(1.0), "100.0%")
        XCTAssertEqual(Fmt.percent(nil), "—")
    }

    func testLatencyFormatting() {
        XCTAssertEqual(Fmt.latency(2_411), "2.4s")
        XCTAssertEqual(Fmt.latency(240), "240ms")
        XCTAssertEqual(Fmt.latency(nil), "—")
    }

    func testISOParsing() {
        XCTAssertNotNil(Fmt.parse("2026-10-23T19:30:06+08:00"))
        XCTAssertNotNil(Fmt.parse("2026-10-23T19:30:06.123Z"))
        XCTAssertNotNil(Fmt.parse("2026-10-23 19:30:06"))
        // 后端纳秒时间戳：ISO8601DateFormatter 只认 3 位小数，必须先截断
        XCTAssertNotNil(Fmt.parse("2026-10-24T03:12:12.930859243+08:00"))
        XCTAssertNotNil(Fmt.parse("2026-10-23T21:26:19.577534335+08:00"))
        XCTAssertEqual(
            Fmt.trimFraction("2026-10-24T03:12:12.930859243+08:00"),
            "2026-10-24T03:12:12.930+08:00"
        )
        XCTAssertNil(Fmt.parse(""))
        XCTAssertNil(Fmt.parse(nil))
    }

    func testAgoFormatting() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let justNow = ISO8601DateFormatter().string(from: now.addingTimeInterval(-30))
        XCTAssertEqual(Fmt.ago(justNow, now: now), "刚刚")

        let fiveMin = ISO8601DateFormatter().string(from: now.addingTimeInterval(-300))
        XCTAssertEqual(Fmt.ago(fiveMin, now: now), "5 分钟前")

        let twoHours = ISO8601DateFormatter().string(from: now.addingTimeInterval(-7_200))
        XCTAssertEqual(Fmt.ago(twoHours, now: now), "2 小时前")

        let twoDays = ISO8601DateFormatter().string(from: now.addingTimeInterval(-172_800))
        XCTAssertEqual(Fmt.ago(twoDays, now: now).count, 5) // MM-dd
    }

    func testCountdown() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let in125s = ISO8601DateFormatter().string(from: now.addingTimeInterval(125))
        XCTAssertEqual(Fmt.countdown(until: in125s, now: now), "2 分 5 秒")

        let past = ISO8601DateFormatter().string(from: now.addingTimeInterval(-10))
        XCTAssertNil(Fmt.countdown(until: past, now: now))
    }

    func testAccountStateLabel() {
        let cooling = Account(
            uid: "u1", nickname: "A", credits: 10, creditsTotal: 100, sessionDeadFails: 0,
            creditsEarliestExpiry: nil, creditsEarliestRemaining: nil, creditsExpiryBuckets: nil,
            cooling: true, until: ISO8601DateFormatter().string(from: Date().addingTimeInterval(120)),
            rateLimitedModels: nil, modelOff: nil, realm: "cn", disabled: false, paused: nil, disabledReason: nil, successCount: 1,
            lastSuccess: nil, lastErr: nil, checkinDone: true, tokenUsage: nil, modelCosts: nil
        )
        XCTAssertTrue(Fmt.accountState(cooling).hasPrefix("冷却中"))

        let healthy = Account(
            uid: "u2", nickname: "B", credits: 10, creditsTotal: 100, sessionDeadFails: 0,
            creditsEarliestExpiry: nil, creditsEarliestRemaining: nil, creditsExpiryBuckets: nil,
            cooling: false, until: nil, rateLimitedModels: nil, modelOff: nil, realm: "cn", disabled: false, paused: nil,
            disabledReason: nil, successCount: 1, lastSuccess: nil, lastErr: nil, checkinDone: true, tokenUsage: nil, modelCosts: nil
        )
        XCTAssertEqual(Fmt.accountState(healthy), "可用")
    }

    func testTokensFormatsBillionsAndMillions() {
        XCTAssertEqual(Fmt.tokens(10_741_866_818), "10.74B")
        XCTAssertEqual(Fmt.tokens(74_600_000), "74.6M")
        XCTAssertEqual(Fmt.tokens(12_100), "12.1k")
        XCTAssertEqual(Fmt.tokens(960), "960")
        XCTAssertEqual(Fmt.tokens(nil), "—")
    }
}
