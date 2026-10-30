import SwiftUI

/// 分组维度切换 + 排行条形图：控制与结果放在同一段，避免控件和结果分离。
struct DataBreakdownSection: View {
    @Binding var dimension: UsageDimension
    @Binding var metric: UsageMetric
    let snapshot: UsageSnapshot

    private var groups: [UsageGroup] {
        metric.sorted(dimension.groups(in: snapshot))
    }

    var body: some View {
        VStack(spacing: Metrics.m) {
            Picker("统计维度", selection: $dimension) {
                ForEach(UsageDimension.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("统计维度")

            UsageBarChart(
                title: "\(metric.title) · \(dimension.noun)",
                groups: groups,
                metric: $metric
            )
        }
    }
}
