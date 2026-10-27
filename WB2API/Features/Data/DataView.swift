import SwiftUI

/// 「数据」Tab：用量总览（按账号 / 模型 / 域），并通往积分与余额历史。
struct DataView: View {
    @Environment(SessionStore.self) private var session
    @State private var loader = Loader<UsageSnapshot>()
    @State private var dimension: UsageDimension = .account
    @State private var range: UsageRange = .days7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.l) {
                    UsageRangePicker(selection: $range)
                        .onChange(of: range) { _, newValue in changeRange(newValue) }

                    TodayUsageCard(today: today, isLoading: loader.isLoading && loader.value == nil)
                        .staggeredAppear(index: 0)

                    UsageRangeSummaryCard(range: range, totals: loader.value?.totals)
                        .staggeredAppear(index: 1)

                    Picker("统计维度", selection: $dimension) {
                        ForEach(UsageDimension.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("统计维度")

                    if let error = loader.error {
                        ErrorBanner(message: error, retry: retry)
                    }

                    if loader.isLoading && loader.value == nil {
                        LoadingSkeleton(rows: 5)
                    } else if let snapshot = loader.value {
                        UsageTotalsGrid(totals: snapshot.totals)
                            .staggeredAppear(index: 2)

                        if dimension.groups(in: snapshot).isEmpty {
                            ContentUnavailableView {
                                Label("暂无分组数据", systemImage: "chart.bar")
                            } description: {
                                Text(dimension.emptyDescription)
                            }
                            .glassCard()
                        } else {
                            UsageBarChart(
                                title: dimension.chartTitle,
                                groups: dimension.groups(in: snapshot)
                            )
                            .staggeredAppear(index: 2)
                            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0.6)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.98)
                            }
                        }

                        DataHistoryLinks()
                            .staggeredAppear(index: 3)
                    } else {
                        ContentUnavailableView {
                            Label("暂无用量数据", systemImage: "chart.bar.xaxis")
                        } description: {
                            Text("先在面板产生一次请求，或下拉刷新。")
                        }
                        .glassCard()
                    }
                }
                .padding(Metrics.m)
                .animation(Motion.numeric, value: dimension)
                .animation(Motion.numeric, value: range)
            }
            .background(.background)
            .navigationTitle("数据")
            .refreshable { await load() }
            .task { await load() }
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

    private var today: UsageTodayTotals? {
        guard let snapshot = loader.value else { return nil }
        return UsageToday.totals(in: snapshot)
    }

    // MARK: - 动作

    private func load() async {
        guard let client = session.client() else { return }
        let hours = range.hours
        await loader.load { try await client.usage(hours: hours) }
    }

    private func refresh() {
        Task { await load() }
    }

    /// 切区间 = 换一组数据，重新拉（range 已被 onChange 赋值）。
    private func changeRange(_ newValue: UsageRange) {
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
