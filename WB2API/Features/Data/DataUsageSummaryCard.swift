import SwiftUI

/// 数据页主摘要：区间 tokens / 请求 / 积分 / 日均（单日显示平均速度）+ 质量指标。
///
/// 今日/昨日已经是区间选项，这里不再混入独立的今日卡。
struct DataUsageSummaryCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let range: UsageRange
    let totals: UsageTotals?
    var isRefreshing = false

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

    private var speedText: String {
        guard let speed = totals?.avgTokensPerSecond, speed > 0 else { return "—" }
        return "\(speed.formatted(.number.precision(.fractionLength(0)))) tok/s"
    }

    private var errorTint: Color {
        (errors ?? 0) > 0 ? .orange : .primary
    }

    private var cardTitle: String {
        switch range {
        case .today: return "今日消耗"
        case .yesterday: return "昨日消耗"
        default: return "区间消耗"
        }
    }

    /// 普通字号三列；辅助功能字号两列，避免数值被压得太小。
    private var metricColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: Metrics.s, alignment: .leading), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cardTitle)
                        .font(.headline)
                    Text(range.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .accessibilityLabel("正在刷新用量")
                }
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

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: Metrics.m) {
                DataMetricCell(title: "请求", value: Fmt.compact(requests))
                DataMetricCell(title: "积分", value: Fmt.creditsDouble(credits))
                DataMetricCell(
                    title: range.isSingleDay ? "每请求均速" : "日均",
                    value: range.isSingleDay ? speedText : dailyText
                )
                DataMetricCell(title: "错误数", value: Fmt.compact(errors), tint: errorTint)
                DataMetricCell(title: "平均延迟", value: Fmt.latency(totals?.avgLatencyMs))
                DataMetricCell(title: "缓存命中", value: Fmt.rate(totals?.cacheHitRate))
            }

            // 面板的 avg_tokens_per_second 是「每次请求 tok/s 的简单平均」，
            // 不是按生成时长加权；短请求权重和长请求一样，读数会明显偏高。
            // 这里把口径写清楚，避免和账号详情 / 日志里的单次实测值对不上。
            if range.isSingleDay, totals?.avgTokensPerSecond != nil {
                Text("每请求简单平均，短请求会拉高读数；单次实测见账号详情")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Metrics.m)
        .glassCard(padding: 0, cornerRadius: Metrics.radiusL)
        .motion(Motion.numeric, value: range)
        .motion(Motion.numeric, value: totals?.totalTokens)
    }
}
