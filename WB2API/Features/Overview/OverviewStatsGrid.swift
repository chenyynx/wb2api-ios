import SwiftUI

/// 概览指标网格：积分 / 今日消耗 / 成功率 / 缓存命中。
struct OverviewStatsGrid: View {
    @Environment(\.appTheme) private var theme

    let digest: OverviewDigest

    private let columns = [
        GridItem(.flexible(), spacing: Metrics.s),
        GridItem(.flexible(), spacing: Metrics.s)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Metrics.s) {
            StatTile(
                title: "剩余积分",
                value: Fmt.credits(digest.totalCredits),
                caption: "全部账号合计",
                tint: theme.primary
            )
            StatTile(
                title: "今日消耗",
                value: digest.todayTokensText,
                caption: digest.todayTokens == nil ? "暂无用量数据" : "tokens · 今日"
            )
            StatTile(
                title: "成功率",
                value: Fmt.percent(digest.successRate, digits: 1),
                caption: "成功 / 请求"
            )
            StatTile(
                title: "缓存命中",
                value: Fmt.rate(digest.cacheHitRate),
                caption: "命中 / 输入 token"
            )
        }
        .motion(Motion.numeric, value: digest)
    }
}
