import XCTest
@testable import WB2API

/// 排行口径：排序、缺字段兜底与柱尾文案。
final class UsageMetricTests: XCTestCase {
    private func group(
        _ key: String,
        requests: Int? = nil,
        credits: Double? = nil,
        tokens: Int? = nil
    ) -> UsageGroup {
        UsageGroup(
            key: key,
            extra: nil,
            nickname: nil,
            realm: nil,
            requests: requests,
            errors: nil,
            totalTokens: tokens,
            credits: credits,
            avgLatencyMs: nil
        )
    }

    func testCreditSortPutsBiggestSpenderFirst() {
        let groups = [
            group("a", requests: 100, credits: 12.5, tokens: 1_000),
            group("b", requests: 10, credits: 90, tokens: 200),
            group("c", requests: 50, credits: 40, tokens: 500),
        ]
        XCTAssertEqual(UsageMetric.credits.sorted(groups).compactMap(\.key), ["b", "c", "a"])
    }

    func testMissingCreditsSortLast() {
        let groups = [
            group("a", requests: 1_000, credits: nil, tokens: 1_000_000),
            group("b", requests: 1, credits: 0.4, tokens: 10),
        ]
        XCTAssertEqual(UsageMetric.credits.sorted(groups).compactMap(\.key), ["b", "a"])
        XCTAssertEqual(UsageMetric.credits.value(of: groups[0]), 0)
    }

    func testRequestSortKeepsDescendingOrder() {
        let groups = [
            group("a", requests: 10, credits: 90),
            group("b", requests: 300, credits: 1),
            group("c", requests: 50, credits: 20),
        ]
        XCTAssertEqual(UsageMetric.requests.sorted(groups).compactMap(\.key), ["b", "c", "a"])
    }

    func testTokenSortUsesTotalTokens() {
        let groups = [
            group("a", requests: 10, tokens: 500),
            group("b", requests: 1, tokens: 8_000_000),
        ]
        XCTAssertEqual(UsageMetric.tokens.sorted(groups).compactMap(\.key), ["b", "a"])
    }

    func testEqualCreditsFallBackToRequestCount() {
        let groups = [
            group("a", requests: 10, credits: 5),
            group("b", requests: 99, credits: 5),
        ]
        XCTAssertEqual(UsageMetric.credits.sorted(groups).compactMap(\.key), ["b", "a"])
    }

    func testValueTextMatchesMetricUnit() {
        XCTAssertEqual(UsageMetric.requests.text(for: 1_400), "1.4k")
        XCTAssertEqual(UsageMetric.credits.text(for: 4_522.66), "4522.7")
        XCTAssertEqual(UsageMetric.credits.text(for: 123_456), "123k")
        XCTAssertEqual(UsageMetric.tokens.text(for: 387_800_000), "387.8M")
    }
}
