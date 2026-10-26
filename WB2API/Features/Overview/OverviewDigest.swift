import Foundation

/// 概览页的纯计算层。
///
/// 把 `OverviewResponse` 压成可以直接念给用户听的结论
/// （"8/11 健康"、"1 个冷却中 · 4 分 32 秒后恢复"），
/// 让视图只负责排版，也方便单测。
struct OverviewDigest: Equatable, Sendable {
    let total: Int
    let healthy: Int
    let cooling: Int
    let disabled: Int
    let totalCredits: Int
    let requests: Int
    /// 缓存命中率（来自 usage.totals）
    let cacheHitRate: Double?
    /// 平均延迟（毫秒，来自 usage.totals）
    let avgLatencyMs: Double?
    /// 最近一批积分到期："11-21 · 剩 4,700"
    let earliestExpiry: String?
    let successRate: Double?
    /// 在途并发已占满的账号数（后端 `in_flight_full`，是 `healthy` 的子集；
    /// 只有全部可用账号都占满才意味着新请求真的要等空位）。
    let inFlightFullCount: Int
    let earliestRecovery: String?
    /// 今日消耗 tokens（由 usage 小时桶聚合；无数据为 nil）
    let todayTokens: Int?

    init(overview: OverviewResponse, usage: UsageSnapshot? = nil) {
        let accounts = overview.accounts
        total = overview.total
        healthy = overview.healthy ?? accounts.filter(\.isHealthy).count
        cooling = overview.cooling ?? accounts.filter(\.isCooling).count
        disabled = overview.disabled ?? accounts.filter(\.isDisabled).count
        totalCredits = overview.totalCredits
        requests = accounts.compactMap { $0.tokenUsage?.requestCount }.reduce(0, +)
        cacheHitRate = usage?.totals?.cacheHitRate
        avgLatencyMs = usage?.totals?.avgLatencyMs
        earliestExpiry = Self.earliestExpiryText(in: accounts)
        inFlightFullCount = overview.inFlightFull ?? 0

        let successes = accounts.compactMap(\.successCount).reduce(0, +)
        successRate = requests > 0 ? min(Double(successes) / Double(requests), 1) : nil

        earliestRecovery = Self.earliestRecovery(in: accounts)
        todayTokens = usage.flatMap { Self.todayTokens(in: $0) }
    }

    // MARK: 派生

    var healthyRatio: Double {
        total > 0 ? Double(healthy) / Double(total) : 0
    }

    /// 「8/11」——环里的大号数字。
    var healthLabel: String { "\(healthy)/\(total)" }

    /// 一句人话状态。
    var headline: String {
        guard total > 0 else { return "等待账号接入" }
        if healthy == total { return "池子状态良好" }
        if healthyRatio >= 0.6 { return "部分账号需要关注" }
        return "池子压力较大"
    }

    var coolingLine: String {
        guard cooling > 0 else { return "没有账号在冷却" }
        if let earliestRecovery, let left = Fmt.countdown(until: earliestRecovery) {
            return "\(cooling) 个冷却中 · \(left)后恢复"
        }
        return "\(cooling) 个冷却中"
    }

    var disabledLine: String {
        disabled > 0 ? "\(disabled) 个账号需重新登录" : "没有需要重新登录的账号"
    }

    /// 今日 tokens 的大数表示（74.6M / 4.2B）。
    var todayTokensText: String {
        guard let todayTokens else { return "—" }
        return Fmt.tokens(todayTokens)
    }


    // MARK: 计算

    /// 全部账号里最近一批积分的到期日与剩余量。
    private static func earliestExpiryText(in accounts: [Account]) -> String? {
        let now = Date()
        let candidates: [(Date, Int, String)] = accounts.compactMap { account in
            guard let raw = account.creditsEarliestExpiry,
                  let date = Fmt.parse(raw),
                  date > now else { return nil }
            return (date, account.creditsEarliestRemaining ?? 0, raw)
        }
        guard let first = candidates.min(by: { $0.0 < $1.0 }) else { return nil }
        return "\(Fmt.day(first.2)) · 剩 \(Fmt.credits(first.1)) 分"
    }

    /// 取最早恢复的那个冷却账号的原始时间戳，交给 `Fmt.countdown` 统一格式化。
    private static func earliestRecovery(in accounts: [Account]) -> String? {
        let now = Date()
        let candidates: [(Date, String)] = accounts.compactMap { account in
            guard account.isCooling,
                  let raw = account.until,
                  let date = Fmt.parse(raw),
                  date > now else { return nil }
            return (date, raw)
        }
        return candidates.min { $0.0 < $1.0 }?.1
    }
}

// MARK: - 今日 token

extension OverviewDigest {
    /// 把 usage series 里「今天」的小时桶 total_tokens 相加。
    /// 桶键形如 "2026-10-23T19"（服务器时区）。
    static func todayTokens(in usage: UsageSnapshot, now: Date = Date()) -> Int? {
        let buckets = usage.series ?? []
        guard !buckets.isEmpty else { return nil }

        var eastern8 = Calendar(identifier: .gregorian)
        eastern8.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let prefix = eastern8.dateComponents([.year, .month, .day], from: now)
        guard let y = prefix.year, let m = prefix.month, let d = prefix.day else { return nil }
        let dayKey = String(format: "%04d-%02d-%02d", y, m, d)

        var total = 0
        var hit = false
        for point in buckets {
            guard let key = point.t, key.hasPrefix(dayKey) else { continue }
            hit = true
            total += point.totalTokens ?? point.tokens ?? 0
        }
        return hit ? total : 0
    }
}
