import SwiftUI

/// 概览的用量趋势面板：最近 24 个小时桶的 token 柱状图 + 三个汇总指标。
///
/// 支持拖动/按住查看单个小时的数值（带选中指示），松手回到总量视图。
/// 数据来自 `usage.series`（`{t:"2026-10-24T02", total_tokens, requests}`），
/// 概览本来就会拉 usage（为了「今日消耗」），这里复用同一份快照，不额外请求。
struct UsageTrendCard: View {
    @Environment(\.appTheme) private var theme

    let usage: UsageSnapshot?

    /// 拖动选中的桶索引；nil = 未选中（显示总量）。
    @State private var selectedIndex: Int?

    private var buckets: [UsagePoint] {
        Array((usage?.series ?? []).suffix(24))
    }

    /// 柱体数据：索引 + token 数（ForEach 用 Identifiable，避免元组 key path）。
    private struct TrendBar: Identifiable {
        let id: Int
        let tokens: Int
    }

    private var bars: [TrendBar] {
        buckets.enumerated().map { TrendBar(id: $0.offset, tokens: $0.element.totalTokens ?? $0.element.tokens ?? 0) }
    }

    private var values: [Int] { bars.map(\.tokens) }

    private var peak: Int {
        values.max() ?? 0
    }

    private var totalTokens: Int {
        values.reduce(0, +)
    }

    private var totalRequests: Int {
        buckets.compactMap(\.requests).reduce(0, +)
    }

    /// 当前应高亮的柱：拖动中是选中项，否则没有。
    private var activeIndex: Int? {
        guard let selectedIndex, buckets.indices.contains(selectedIndex) else { return nil }
        return selectedIndex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            SectionHeader(title: "用量趋势", subtitle: subtitle)

            if buckets.isEmpty {
                ContentUnavailableView(
                    "还没有用量数据",
                    systemImage: "chart.bar.xaxis",
                    description: Text("产生请求后，这里会按小时显示 token 消耗")
                )
                .padding(.vertical, Metrics.m)
                .glassCard()
            } else {
                chart
                metrics
            }
        }
        .onDisappear { selectedIndex = nil }
    }

    private var subtitle: String {
        if let activeIndex {
            return headline(for: activeIndex)
        }
        return buckets.isEmpty ? "最近 24 小时" : "最近 \(buckets.count) 小时"
    }

    private func headline(for index: Int) -> String {
        let point = buckets[index]
        let tokens = point.totalTokens ?? point.tokens ?? 0
        let requests = point.requests ?? 0
        return "\(hourLabel(point.t)) · \(Fmt.tokens(tokens)) tokens · \(Fmt.compact(requests)) 次请求"
    }

    // MARK: - 图表

    private var chart: some View {
        VStack(spacing: Metrics.xs) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let slot = width / CGFloat(max(bars.count, 1))
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(bars) { bar in
                            barView(bar)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    // 选中指示：细竖线 + 底部圆点，随手指移动
                    if let activeIndex {
                        indicator(at: CGFloat(activeIndex) * slot + slot / 2, height: proxy.size.height)
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(width: width))
            }
            .frame(height: 76)

            HStack {
                Text(hourLabel(buckets.first?.t))
                Spacer()
                Text(hourLabel(buckets[buckets.count / 2].t))
                Spacer()
                Text(hourLabel(buckets.last?.t))
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .monospacedDigit()
        }
        .padding(Metrics.m)
        .glassCard(padding: 0, cornerRadius: Metrics.radiusM)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAdjustableAction { direction in
            adjustSelection(direction)
        }
    }

    private func barView(_ bar: TrendBar) -> some View {
        let isDimmed = activeIndex != nil && activeIndex != bar.id
        return RoundedRectangle(cornerRadius: 2)
            .fill(barColor(index: bar.id))
            .opacity(isDimmed ? 0.35 : 1)
            .frame(height: barHeight(bar))
            .animation(.snappy(duration: 0.15), value: activeIndex)
            .accessibilityHidden(true)
    }

    /// 选中指示线。
    private func indicator(at x: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(theme.primary)
            .frame(width: 2, height: height)
            .overlay(alignment: .bottom) {
                Circle()
                    .fill(theme.primary)
                    .frame(width: 6, height: 6)
                    .offset(y: 0)
            }
            .position(x: x, y: height / 2)
            .animation(.snappy(duration: 0.1), value: activeIndex)
    }

    // MARK: - 手势

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let slot = width / CGFloat(max(bars.count, 1))
                let index = Int((value.location.x / slot).rounded(.down))
                selectedIndex = min(max(index, 0), bars.count - 1)
            }
            .onEnded { _ in
                // 松手保留选中 1.6s 再回到总量，避免闪没
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    if !Task.isCancelled { selectedIndex = nil }
                }
            }
    }

    /// 辅助功能：上下调节选中的小时。
    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .decrement:
            selectedIndex = max((selectedIndex ?? bars.count - 1) - 1, 0)
        case .increment:
            selectedIndex = min((selectedIndex ?? -1) + 1, bars.count - 1)
        @unknown default:
            break
        }
    }

    private var accessibilitySummary: String {
        if let activeIndex { return headline(for: activeIndex) }
        return "最近 \(buckets.count) 小时用量趋势，峰值 \(Fmt.compact(peak)) tokens；按住图表查看单小时数值"
    }

    private var metrics: some View {
        HStack(spacing: Metrics.s) {
            if let activeIndex {
                let point = buckets[activeIndex]
                metric(title: hourLabel(point.t) + " tokens", value: Fmt.tokens(point.totalTokens ?? point.tokens ?? 0))
                metric(title: "请求", value: Fmt.compact(point.requests))
                metric(title: "该小时积分", value: Fmt.creditsDouble(point.credits))
            } else {
                metric(title: "24h tokens", value: Fmt.tokens(totalTokens))
                metric(title: "请求数", value: Fmt.compact(totalRequests))
                metric(title: "峰值/小时", value: Fmt.compact(peak))
            }
        }
        .animation(.snappy(duration: 0.15), value: activeIndex)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.callout.bold().monospacedDigit())
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.s)
        .glassCard(padding: 0, cornerRadius: Metrics.radiusS)
    }

    // MARK: - 绘制细节

    private func barHeight(_ bar: TrendBar) -> CGFloat {
        guard peak > 0 else { return 2 }
        return max(2, CGFloat(bar.tokens) / CGFloat(peak) * 76)
    }

    /// 最近的桶用主色，往前依次变淡，形成时间梯度。
    private func barColor(index: Int) -> Color {
        let ratio = Double(index + 1) / Double(max(buckets.count, 1))
        return theme.primary.opacity(0.25 + 0.6 * ratio)
    }

    /// "2026-10-24T02" → "02时"；解析失败原样返回。
    private func hourLabel(_ raw: String?) -> String {
        guard let raw, raw.count >= 13 else { return raw ?? "—" }
        let hour = raw.suffix(2)
        return "\(hour)时"
    }
}
