import Foundation

/// 今日消耗：从 usage 的小时桶里按东八区自然日聚合，和所选区间无关。
struct UsageTodayTotals: Equatable, Sendable {
    let tokens: Int
    let requests: Int
    let credits: Double
    /// "2026-10-27"
    let dayKey: String

    /// "10-27"
    var dayLabel: String {
        String(dayKey.dropFirst(5))
    }
}

enum UsageToday {
    /// 小时桶 `t` 形如 "2026-10-27T14"（服务器东八区）。
    static func totals(in snapshot: UsageSnapshot, now: Date = Date()) -> UsageTodayTotals? {
        guard let series = snapshot.series, !series.isEmpty else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        let dayKey = String(format: "%04d-%02d-%02d", year, month, day)

        var tokens = 0
        var requests = 0
        var credits = 0.0
        var hasToday = false

        for point in series {
            guard let timestamp = point.t, timestamp.hasPrefix(dayKey) else { continue }
            hasToday = true
            tokens += point.totalTokens ?? point.tokens ?? 0
            requests += point.requests ?? 0
            credits += point.credits ?? 0
        }

        guard hasToday else { return nil }
        return UsageTodayTotals(tokens: tokens, requests: requests, credits: credits, dayKey: dayKey)
    }
}
