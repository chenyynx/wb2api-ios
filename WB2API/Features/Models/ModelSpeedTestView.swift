import SwiftUI

/// 模型输出速度测试：逐个模型跑固定 prompt，测 TTFB 与首字后的 tok/s。
struct ModelSpeedTestView: View {
    @Environment(\.appTheme) private var theme

    @Environment(SessionStore.self) private var session
    @State private var models = Loader<ModelsResponse>()
    @State private var runner = ModelSpeedRunner()
    @State private var searchText = ""
    @State private var sortBySpeed = false
    @State private var didAutoStart = false
    @State private var showRunConfirm = false

    /// 从模型详情进来时，打开页面直接测这一个模型。
    private let focus: ModelInfo?

    init(focus: ModelInfo? = nil) {
        self.focus = focus
    }

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

            if isInitialLoading {
                Section {
                    LoadingSkeleton(rows: 6)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else if !allModels.isEmpty {
                summarySection
                modelsSection
            } else {
                Section {
                    ContentUnavailableView(
                        "暂无模型",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("面板还没有返回模型目录")
                    )
                }
            }
        }
        .navigationTitle("输出速度")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索模型 ID 或描述")
        .refreshable { await load(force: true) }
        .task { await load() }
        .onDisappear { runner.stop() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("排序", selection: $sortBySpeed) {
                        Text("目录顺序").tag(false)
                        Text("速度优先").tag(true)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("排序方式")
            }
        }
        .confirmationDialog("开始全部测速？", isPresented: $showRunConfirm, titleVisibility: .visible) {
            Button("测 \(visibleModels.count) 个模型") {
                runner.startAll(visibleModels)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("每个模型会发一次最多 \(ModelSpeedRunner.maxTokens) tokens 的请求，会消耗少量积分。")
        }
    }

    // MARK: - 区块

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: Metrics.m) {
                HStack(alignment: .top, spacing: Metrics.s) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("输出 Token 速度")
                            .font(.headline)
                        Text("固定 prompt · 最多 \(ModelSpeedRunner.maxTokens) tokens · 串行测试")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if runner.isRunning {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("正在测速")
                    }
                }

                if let best = runner.bestResult, let model = bestModel {
                    HStack(alignment: .firstTextBaseline, spacing: Metrics.s) {
                        Text(best.tokensPerSecond, format: .number.precision(.fractionLength(1)))
                            .font(.metric(.largeTitle))
                            .foregroundStyle(theme.primary)
                            .contentTransition(.numericText())
                        Text("tok/s")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Text(model.displayID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: Metrics.m) {
                    Button(action: toggleRun) {
                        Label(
                            runner.isRunning ? "停止" : "全部测速",
                            systemImage: runner.isRunning ? "stop.fill" : "speedometer"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(runner.isRunning ? .red : theme.primary)

                    if runner.isRunning {
                        Text("\(runner.completed)/\(runner.total)")
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else {
                        Text("已测 \(runner.testedCount)/\(allModels.count)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                if let current = runner.currentModelID {
                    Text("正在测 \(current)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, Metrics.xs)
        } header: {
            Text("测速")
        } footer: {
            Text("会真实消耗少量积分；tok/s 只算首字之后，TTFB 单独展示。结果保存在本机，离开页面会停止测速。")
        }
    }

    private var modelsSection: some View {
        Section {
            ForEach(visibleModels) { model in
                ModelSpeedTestRow(
                    model: model,
                    result: runner.result(for: model),
                    state: runner.state(for: model),
                    isRunning: runner.isRunning,
                    onTest: { runner.start(model) }
                )
            }
        } header: {
            HStack(spacing: Metrics.s) {
                Text("模型")
                Spacer(minLength: 0)
                Text("\(visibleModels.count) 个")
                    .monospacedDigit()
            }
        } footer: {
            Text("点右侧 ▶ 单独测；全部测速会按当前列表顺序逐个跑。")
        }
    }

    // MARK: - 派生

    private var isInitialLoading: Bool {
        models.value == nil && models.error == nil
    }

    private var allModels: [ModelInfo] {
        models.value?.models ?? []
    }

    private var visibleModels: [ModelInfo] {
        var list = allModels
        if !searchText.isEmpty {
            list = list.filter { model in
                model.displayID.localizedStandardContains(searchText)
                    || (model.name ?? "").localizedStandardContains(searchText)
                    || (model.description ?? "").localizedStandardContains(searchText)
            }
        }
        guard sortBySpeed else { return list }
        return list.sorted { lhs, rhs in
            let left = runner.result(for: lhs)?.tokensPerSecond ?? -1
            let right = runner.result(for: rhs)?.tokensPerSecond ?? -1
            if left == right { return lhs.displayID < rhs.displayID }
            return left > right
        }
    }

    private var bestModel: ModelInfo? {
        guard let best = runner.bestResult else { return nil }
        return allModels.first { $0.displayID == best.modelID }
    }

    // MARK: - 动作

    private func toggleRun() {
        if runner.isRunning {
            runner.stop()
        } else {
            showRunConfirm = true
        }
    }

    private func retry() {
        Task { await load(force: true) }
    }

    private func load(force: Bool = false) async {
        guard let client = session.client() else { return }
        await models.load(force: force) {
            try await client.models()
        }
        if let list = models.value?.models {
            runner.configure(client: client, models: list)
        }
        if let focus, !didAutoStart {
            didAutoStart = true
            runner.start(focus)
        }
    }
}

/// 单个模型行：结果在右，播放按钮单独测。
private struct ModelSpeedTestRow: View {
    @Environment(\.appTheme) private var theme

    let model: ModelInfo
    let result: ModelSpeedResult?
    let state: ModelSpeedState
    let isRunning: Bool
    let onTest: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.m) {
            VStack(alignment: .leading, spacing: Metrics.xs) {
                Text(model.displayID)
                    .font(.callout.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                details
            }

            Spacer(minLength: 0)

            if let result, showsResult {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(result.tokensPerSecond, format: .number.precision(.fractionLength(1)))
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(theme.primary)
                    Text("tok/s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .contentTransition(.numericText())
            }

            Button(action: onTest) {
                Image(systemName: "play.fill")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .disabled(isRunning)
            .accessibilityLabel("测试 \(model.displayID) 的输出速度")
        }
        .padding(.vertical, 2)
    }

    private var showsResult: Bool {
        switch state {
        case .running, .failed: return false
        case .success, .idle: return true
        }
    }

    @ViewBuilder
    private var details: some View {
        switch state {
        case .running:
            HStack(spacing: Metrics.xs) {
                ProgressView()
                    .controlSize(.mini)
                Text("测试中…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)

        case .success, .idle:
            if let result {
                Text("TTFB \(Fmt.latency(Double(result.ttfbMs))) · \(result.completionTokens) tokens\(result.estimated ? " ≈" : "") · \(Fmt.ago(result.measuredAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("未测")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
