import SwiftUI

/// 「数据」Tab：一张主摘要卡 + 分组条形图 + 历史入口。
struct DataView: View {
    @Environment(\.appTheme) private var theme

    @Environment(SessionStore.self) private var session
    @State private var loader = Loader<UsageSnapshot>()
    @State private var dimension: UsageDimension = .account
    /// 排行口径持久化：默认按积分消耗，直接回答「哪个模型最烧积分」。
    @AppStorage("wb2api.usageMetric") private var metric: UsageMetric = .credits
    @State private var range: UsageRange = .days7

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.l) {
                    UsageRangePicker(selection: $range)

                    if let error = loader.error {
                        ErrorBanner(message: error, retry: retry)
                    }

                    DataUsageSummaryCard(
                        range: range,
                        totals: loader.value?.totals,
                        isRefreshing: loader.isLoading
                    )

                    if isInitialLoading {
                        LoadingSkeleton(rows: 4)
                    } else if let snapshot = loader.value {
                        DataBreakdownSection(
                            dimension: $dimension,
                            metric: $metric,
                            snapshot: snapshot
                        )
                        DataHistoryLinks()
                    } else if loader.error == nil {
                        ContentUnavailableView {
                            Label("暂无用量数据", systemImage: "chart.bar.xaxis")
                        } description: {
                            Text("先在面板产生一次请求，或下拉刷新。")
                        }
                        .glassCard()
                    }
                }
                .padding(.horizontal, Metrics.m)
                .padding(.top, Metrics.s)
                .padding(.bottom, Metrics.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .background {
                LinearGradient(
                    colors: [theme.soft.opacity(0.7), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
            .background(.background)
            .navigationTitle("数据")
            .refreshable { await load() }
            .task(id: range) { await load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新", systemImage: "arrow.clockwise", action: refresh)
                        .disabled(loader.isLoading)
                }
            }
            .navigationDestination(for: DataRoute.self) { route in
                switch route {
                case .creditHistory: CreditHistoryView()
                case .balanceHistory: BalanceHistoryView()
                }
            }
        }
    }

    // MARK: - 派生

    private var isInitialLoading: Bool {
        loader.isLoading && loader.value == nil
    }

    // MARK: - 动作

    private func load() async {
        guard let client = session.client() else { return }
        if let window = range.window() {
            await loader.load(force: true) {
                try await client.usage(from: window.from, to: window.to)
            }
        } else {
            await loader.load(force: true) {
                try await client.usage(hours: range.hours)
            }
        }
    }

    private func refresh() {
        Task { await load() }
    }

    private func retry() {
        loader.clearError()
        Task { await load() }
    }
}

#Preview {
    DataView()
        .environment(SessionStore())
}
