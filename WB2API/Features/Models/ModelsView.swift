import SwiftUI

/// 模型目录：搜索 + 默认/繁忙标记 + 详情导航 + 探测结果弹层。
struct ModelsView: View {
    @Environment(\.appTheme) private var theme

    @Environment(SessionStore.self) private var session

    @State private var models = Loader<ModelsResponse>()
    @State private var probes = Loader<JSONValue>()
    @State private var searchText = ""
    @State private var isShowingProbes = false

    var body: some View {
        List {
            if let message = models.error {
                Section {
                    ErrorBanner(message: message, retry: retry)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                NavigationLink {
                    ModelSpeedTestView()
                } label: {
                    HStack(spacing: Metrics.m) {
                        Image(systemName: "speedometer")
                            .font(.title3)
                            .foregroundStyle(theme.primary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("输出速度测试")
                                .font(.callout.bold())
                            Text("逐个测每个模型的 tok/s 与首字延迟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("固定 prompt、串行测试，会消耗少量积分。")
            }

            Section {
                if isInitialLoading {
                    LoadingSkeleton(rows: 6)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if visibleModels.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            "暂无模型",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("面板还没有返回模型目录")
                        )
                    } else {
                        ContentUnavailableView.search
                    }
                } else {
                    ForEach(visibleModels) { model in
                        NavigationLink(value: model) {
                            ModelRowView(model: model)
                        }
                    }
                }
            } header: {
                HStack(spacing: Metrics.s) {
                    Text("模型目录")
                    Spacer(minLength: 0)
                    Text("\(visibleModels.count) 个")
                        .monospacedDigit()
                }
            } footer: {
                Text("来源 · \(models.value?.globalSource ?? "—")")
            }
        }
        .navigationTitle("模型")
        .searchable(text: $searchText, prompt: "搜索模型 ID 或描述")
        .refreshable { await refreshModels() }
        .navigationDestination(for: ModelInfo.self) { model in
            ModelDetailView(model: model)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("模型探测", systemImage: "waveform.path.ecg", action: openProbes)
                    .labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新", systemImage: "arrow.clockwise", action: refresh)
                    .labelStyle(.iconOnly)
            }
        }
        .sheet(isPresented: $isShowingProbes) {
            NavigationStack {
                ProbeResultView(probes: probes.value)
                    .navigationTitle("模型探测")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成", action: closeProbes)
                        }
                    }
                    .task { await refreshProbes() }
            }
        }
        .task { await refreshModels() }
    }

    private var isInitialLoading: Bool {
        models.value == nil && models.error == nil
    }

    private var visibleModels: [ModelInfo] {
        let all = models.value?.models ?? []
        guard !searchText.isEmpty else { return all }
        return all.filter { model in
            model.displayID.localizedStandardContains(searchText)
                || (model.name ?? "").localizedStandardContains(searchText)
                || (model.description ?? "").localizedStandardContains(searchText)
        }
    }

    // MARK: - 加载

    private func refresh() {
        Task { await refreshModels() }
    }

    private func retry() {
        Task { await refreshModels() }
    }

    private func refreshModels() async {
        guard let client = session.client() else { return }
        await models.load { try await client.models() }
    }

    private func refreshProbes() async {
        guard let client = session.client() else { return }
        await probes.load { try await client.modelProbes() }
    }

    // MARK: - 探测弹层

    private func openProbes() {
        isShowingProbes = true
    }

    private func closeProbes() {
        isShowingProbes = false
    }
}
