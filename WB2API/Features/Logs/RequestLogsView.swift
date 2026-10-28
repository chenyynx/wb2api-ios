import SwiftUI

/// 请求日志：请求指标块 + 最近请求流水。
struct RequestLogsView: View {
    @Environment(\.appTheme) private var theme

    @Environment(SessionStore.self) private var session

    @State private var metrics = Loader<RequestMetrics>()
    @State private var logs = Loader<JSONValue>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.m) {
                if let message = metrics.error ?? logs.error {
                    ErrorBanner(message: message, retry: retry)
                }

                if let value = metrics.value {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: Metrics.s)],
                        spacing: Metrics.s
                    ) {
                        StatTile(title: "完成请求", value: value.completedLabel, caption: value.startedAtLabel)
                        StatTile(title: "成功", value: value.succeededLabel, tint: .green)
                        StatTile(title: "失败", value: value.failedLabel, tint: .red)
                        StatTile(
                            title: "成功率",
                            value: value.successRateLabel,
                            caption: "HTTP \(value.httpSuccessRateLabel)",
                            tint: theme.primary
                        )
                        StatTile(title: "平均耗时", value: value.avgDurationLabel)
                        StatTile(title: "进行中", value: value.inFlightLabel, caption: "此刻仍在处理")
                    }
                } else if metrics.isLoading || metrics.error == nil {
                    LoadingSkeleton(rows: 2)
                }

                SectionHeader(title: "请求明细", subtitle: "最近 \(rows.count) 条")

                if rows.isEmpty {
                    ContentUnavailableView(
                        "暂无请求",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("网关还没有处理过请求")
                    )
                    .padding(.vertical, Metrics.l)
                } else {
                    LazyVStack(spacing: Metrics.s) {
                        ForEach(rows) { row in
                            RequestLogRowView(row: row)
                        }
                    }
                }
            }
            .padding(Metrics.m)
        }
        .navigationTitle("请求日志")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refreshAll() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新", systemImage: "arrow.clockwise", action: refresh)
                    .labelStyle(.iconOnly)
            }
        }
        .task { await refreshAll() }
    }

    private var rows: [RequestLogRow] {
        (logs.value ?? .null).rows.enumerated().map { offset, item in
            RequestLogRow(index: offset, value: item)
        }
    }

    private func refresh() {
        Task { await refreshAll() }
    }

    private func retry() {
        Task { await refreshAll() }
    }

    private func refreshAll() async {
        guard let client = session.client() else { return }
        await metrics.load { try await client.requestMetrics() }
        await logs.load { try await client.requestLogs(limit: 150) }
    }
}
