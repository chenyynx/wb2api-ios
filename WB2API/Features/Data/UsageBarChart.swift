import Charts
import SwiftUI

/// 分组排行卡：柱长、柱尾数值和排序都由 `metric` 决定，右上角可直接切换口径。
struct UsageBarChart: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let groups: [UsageGroup]
    @Binding var metric: UsageMetric
    var limit: Int = 8

    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 40

    private var items: [UsageGroup] {
        Array(groups.prefix(limit))
    }

    /// 给尾注留出空间，避免最长的柱子和数值顶出画布。
    private var xUpperBound: Double {
        let maximum = items.map { metric.value(of: $0) }.max() ?? 0
        return max(maximum * 1.25, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            header

            if items.isEmpty {
                ContentUnavailableView {
                    Label("暂无分组数据", systemImage: "chart.bar")
                } description: {
                    Text("换一个维度或刷新后再看。")
                }
                .frame(minHeight: 180)
            } else {
                chart
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .motion(Motion.numeric, value: metric)
        .motion(Motion.numeric, value: items.map(\.id))
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if !items.isEmpty {
                    Text("共 \(groups.count) 项 · 取前 \(items.count) 项")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            metricMenu
        }
    }

    /// 排序口径入口：胶囊按钮 + 系统菜单，选中项打勾。
    private var metricMenu: some View {
        Menu {
            Picker("排序口径", selection: $metric) {
                ForEach(UsageMetric.allCases) { item in
                    Label(item.title, systemImage: item.symbol).tag(item)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption2.weight(.bold))
                Text(metric.shortTitle)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(theme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background { Capsule().fill(theme.soft) }
            .contentShape(.capsule)
        }
        .accessibilityLabel("排序口径，当前 \(metric.title)")
    }

    // MARK: - 图表

    private var chart: some View {
        Chart(items) { group in
            BarMark(
                x: .value(title, metric.value(of: group)),
                y: .value("分组", label(for: group))
            )
            .foregroundStyle(theme.gradient)
            .cornerRadius(Metrics.xs)
            // 尾注不要加 .contentTransition(.numericText())：口径切换时 Charts 会复用
            // annotation 视图，数字过渡中的旧字形会和新数字叠在一起（实测出现多余笔画）。
            .annotation(position: .trailing, alignment: .center, spacing: Metrics.s) {
                Text(metric.text(for: metric.value(of: group)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .chartXAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: 0...xUpperBound)
        .frame(height: CGFloat(items.count) * rowHeight + Metrics.l)
        .accessibilityLabel(title)
    }

    /// 类目标签过长会挤掉柱体，截断后仍保留可辨识前缀。
    /// 账号维度用昵称（key 是 uid），域维度用中文名。
    private func label(for group: UsageGroup) -> String {
        let raw = group.displayName
        return raw.count > 12 ? String(raw.prefix(11)) + "…" : raw
    }
}
