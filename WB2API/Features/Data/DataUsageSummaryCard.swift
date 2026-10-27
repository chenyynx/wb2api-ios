import SwiftUI

/// 数据页主摘要：区间 tokens/请求/积分/日均 + 质量指标 + 今日消耗。
///
/// 把原先「区间卡 + 六格指标 + 今日卡」三块合成一张，避免重复数字和过长页面。
struct DataUsageSummaryCard: View {
    let range: UsageRange
    let totals: UsageTotals?
    let today: UsageTodayTotals?
    let isLoading: Bool

    private var tokens: Int? { totals?.totalTokens }
    private var requests: Int? { totals?.requests }
    private var credits: Double? { totals?.credits }
    private var errors: Int? { totals?.errors }

    private var dailyTokens: Int? {
        guard let tokens, tokens > 0 else { return nil }
        let days = range.days(coveredHours: 24 * 30)
        return Int(Double(tokens) / days)
    }

    private var dailyText: String {
        guard let dailyTokens else { return "—" }
        return Fmt.tokens(dailyTokens)
    }

    private var errorTint: Color {
        (errors ?? 0) > 0 ? .orange : .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("区间消耗")
                    .font(.headline)
                Text(range.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: Metrics.xs) {
                Text(Fmt.tokens(tokens))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text("tokens")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: Metrics.s) {
                DataMetricCell(title: "请求", value: Fmt.compact(requests))
                DataMetricCell(title: "积分", value: Fmt.creditsDouble(credits))
                DataMetricCell(title: "日均", value: dailyText)
            }

            Divider()

            HStack(alignment: .top, spacing: Metrics.s) {
                DataMetricCell(title: "错误数", value: Fmt.compact(errors), tint: errorTint)
                DataMetricCell(title: "平均延迟", value: Fmt.latency(totals?.avgLatencyMs))
                DataMetricCell(title: "缓存命中", value: Fmt.rate(totals?.cacheHitRate))
            }

            TodayUsageSection(today: today, isLoading: isLoading)
        }
        .padding(Metrics.m)
        .glassCard(padding: 0, cornerRadius: Metrics.radiusL)
        .motion(Motion.numeric, value: range)
        .motion(Motion.numeric, value: totals?.totalTokens)
    }
}
