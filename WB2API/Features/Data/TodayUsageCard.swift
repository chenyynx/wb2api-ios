import SwiftUI

/// 「数据」页顶部的今日消耗：与 3/7/30 天区间互不影响。
struct TodayUsageCard: View {
    let today: UsageTodayTotals?
    var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            SectionHeader(
                title: "今日消耗",
                subtitle: today.map { "\($0.dayLabel) · 自然日" } ?? "今天"
            )

            VStack(alignment: .leading, spacing: Metrics.s) {
                if isLoading {
                    HStack(spacing: Metrics.s) {
                        ProgressView()
                            .controlSize(.small)
                        Text("加载今日用量…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let today {
                    HStack(alignment: .firstTextBaseline, spacing: Metrics.xs) {
                        Text(Fmt.tokens(today.tokens))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("tokens")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: Metrics.s) {
                        stat("请求", Fmt.compact(today.requests))
                        stat("积分", Fmt.creditsDouble(today.credits))
                    }
                } else {
                    Text("今天还没有用量记录")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.m)
            .glassCard(padding: 0, cornerRadius: Metrics.radiusM)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.callout.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
