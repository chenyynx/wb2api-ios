import SwiftUI

/// 分组维度切换 + 条形图：控制与图表放在同一段，避免控件和结果分离。
struct DataBreakdownSection: View {
    @Binding var dimension: UsageDimension
    let snapshot: UsageSnapshot

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
                title: dimension.chartTitle,
                groups: dimension.groups(in: snapshot)
            )
        }
    }
}
