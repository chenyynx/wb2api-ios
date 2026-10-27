import SwiftUI

/// 摘要卡内的今日消耗区块：浅紫底，和区间数据分开但不另起一张大卡。
struct TodayUsageSection: View {
    let today: UsageTodayTotals?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            HStack(alignment: .firstTextBaseline) {
                Label("今日消耗", systemImage: "sun.max.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Accent.primary)
                Spacer(minLength: 0)
                if let today {
                    Text(today.dayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading && today == nil {
                HStack(spacing: Metrics.s) {
                    ProgressView()
                        .controlSize(.small)
                    Text("加载今日用量…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let today {
                VStack(alignment: .leading, spacing: Metrics.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: Metrics.xs) {
                        Text(Fmt.tokens(today.tokens))
                            .font(.title2.bold())
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(Fmt.compact(today.requests)) 请求 · \(Fmt.creditsDouble(today.credits)) 积分")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("今天还没有用量记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Metrics.m)
        .background(Accent.soft.opacity(0.65), in: .rect(cornerRadius: Metrics.radiusM))
        .motion(Motion.numeric, value: today?.tokens)
    }
}
