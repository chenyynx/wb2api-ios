import Charts
import SwiftUI

/// 用量条形图：按分组展示请求数，尾注给出同样直观的数量级。
struct UsageBarChart: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let groups: [UsageGroup]
    var limit: Int = 8

    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 40

    private var items: [UsageGroup] {
        Array(groups.prefix(limit))
    }

    /// 给尾注留出空间，避免最长的那根柱子把数字顶出画布。
    private var xUpperBound: Double {
        let maximum = items.compactMap(\.requests).max() ?? 0
        return max(Double(maximum) * 1.25, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if !items.isEmpty {
                    Text("共 \(groups.count) 项 · 取前 \(items.count) 项")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if items.isEmpty {
                ContentUnavailableView {
                    Label("暂无分组数据", systemImage: "chart.bar")
                } description: {
                    Text("换一个维度或刷新后再看。")
                }
                .frame(minHeight: 180)
            } else {
                Chart(items) { group in
                    BarMark(
                        x: .value("请求数", group.requests ?? 0),
                        y: .value("分组", label(for: group))
                    )
                    .foregroundStyle(theme.gradient)
                    .cornerRadius(Metrics.xs)
                    .annotation(position: .trailing, alignment: .center, spacing: Metrics.xs) {
                        Text(Fmt.compact(group.requests))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .chartXAxis(.hidden)
                .chartLegend(.hidden)
                .chartXScale(domain: 0...xUpperBound)
                .frame(height: CGFloat(items.count) * rowHeight + Metrics.l)
                .motion(Motion.numeric, value: items.map(\.id))
                .accessibilityLabel(title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// 类目标签过长会挤掉柱体，截断后仍保留可辨识前缀。
    /// 账号维度用昵称（key 是 uid），域维度用中文名。
    private func label(for group: UsageGroup) -> String {
        let raw = group.displayName
        return raw.count > 12 ? String(raw.prefix(11)) + "…" : raw
    }
}
