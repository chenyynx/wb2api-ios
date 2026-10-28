import SwiftUI

/// 余额趋势：7 / 14 / 30 天折线，附各账号汇总与每日变化。
struct BalanceHistoryView: View {
    @Environment(\.appTheme) private var theme

    @Environment(SessionStore.self) private var session
    @State private var loader = Loader<BalanceHistory>()
    @State private var days = 7

    private var seriesList: [BalanceSeries] {
        loader.value?.series ?? []
    }

    private var totalCurrent: Int {
        seriesList.compactMap(\.current).reduce(0, +)
    }

    var body: some View {
        List {
            Section {
                Picker("时间区间", selection: $days) {
                    Text("7 天").tag(7)
                    Text("14 天").tag(14)
                    Text("30 天").tag(30)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("时间区间")
            }

            if let error = loader.error {
                Section {
                    ErrorBanner(message: error, retry: retry)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if loader.isLoading && loader.value == nil {
                Section {
                    LoadingSkeleton(rows: 5)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            } else if seriesList.isEmpty {
                ContentUnavailableView {
                    Label("暂无余额数据", systemImage: "chart.xyaxis.line")
                } description: {
                    Text("面板还没有生成余额快照。")
                }
                .listRowSeparator(.hidden)
            } else {
                Section {
                    LabeledContent("总余额") {
                        Text(Fmt.credits(totalCurrent))
                            .font(.metricSmall())
                            .foregroundStyle(theme.primary)
                            .contentTransition(.numericText())
                    }
                    LabeledContent("账号数", value: "\(seriesList.count)")
                    LabeledContent("区间", value: "\(days) 天")
                } header: {
                    Text("概览")
                }

                Section {
                    BalanceLineChart(series: seriesList)
                        .listRowInsets(EdgeInsets(
                            top: Metrics.s,
                            leading: Metrics.s,
                            bottom: Metrics.s,
                            trailing: Metrics.m
                        ))
                } header: {
                    Text("余额曲线")
                } footer: {
                    Text("单位：积分 · 曲线来自面板余额快照")
                }

                Section("账号明细") {
                    ForEach(seriesList) { series in
                        LabeledContent {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Fmt.credits(series.current))
                                    .font(.body.monospacedDigit())
                                    .contentTransition(.numericText())
                                Text(changeText(series.change))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(displayName(series))
                                Text(realmLabel(series.realm))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                ForEach(seriesList) { series in
                    if let daily = series.daily, !daily.isEmpty {
                        Section {
                            DisclosureGroup {
                                ForEach(daily) { day in
                                    LabeledContent {
                                        Text(dayText(day))
                                            .font(.footnote.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    } label: {
                                        Text(Fmt.day(day.day))
                                    }
                                }
                            } label: {
                                Label("每日变化", systemImage: "calendar")
                            }
                        } header: {
                            Text(displayName(series))
                        }
                    }
                }
            }
        }
        .navigationTitle("余额趋势")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task(id: days) { await load() }
    }

    // MARK: - 动作

    private func load() async {
        guard let client = session.client() else { return }
        await loader.load { try await client.balanceHistory(days: days) }
    }

    private func retry() {
        loader.clearError()
        Task { await load() }
    }

    // MARK: - 展示

    private func displayName(_ series: BalanceSeries) -> String {
        if let name = series.name, !name.isEmpty { return name }
        if let uid = series.uid, !uid.isEmpty { return String(uid.prefix(8)) }
        return "未知账号"
    }

    private func realmLabel(_ realm: String?) -> String {
        switch realm {
        case "cn": "国内版"
        case "global": "国际版"
        case .some(let other): other
        case .none: "—"
        }
    }

    private func changeText(_ change: Int?) -> String {
        guard let change else { return "—" }
        if change > 0 { return "+\(change)" }
        return "\(change)"
    }

    private func dayText(_ day: BalanceDaily) -> String {
        let consumed = day.consumed.map { "消耗 \($0)" } ?? "消耗 —"
        let gained = day.gained.map { "入账 \($0)" } ?? "入账 —"
        return "\(consumed) · \(gained)"
    }
}
