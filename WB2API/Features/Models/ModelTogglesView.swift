import SwiftUI

/// 模型开关：手动关闭某账号的某些模型（关闭后该账号不再被路由到这些模型）。
///
/// 状态来自 `overview.accounts[].model_off`，写入走 `POST accounts/{uid}/model_toggle`
/// （后端字段是 `off`，不是 `enabled`）。
struct ModelTogglesView: View {
    @Environment(\.appTheme) private var theme

    let account: Account

    @Environment(SessionStore.self) private var session
    @State private var models: [ModelInfo] = []
    @State private var offModels: Set<String> = []
    @State private var query = ""
    @State private var isLoading = false
    @State private var busy: Set<String> = []
    @State private var errorText: String?
    @State private var toast: Toast?

    private var realmPrefix: String {
        account.realm == "global" ? "global:" : "cn:"
    }

    private var filtered: [ModelInfo] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = models.filter { model in
            guard !keyword.isEmpty else { return true }
            let name = displayName(model)
            return name.localizedCaseInsensitiveContains(keyword)
                || modelID(model).localizedCaseInsensitiveContains(keyword)
        }
        // 同域优先，其次按名称，便于查找
        return list.sorted { lhs, rhs in
            let l = modelID(lhs).hasPrefix(realmPrefix)
            let r = modelID(rhs).hasPrefix(realmPrefix)
            if l != r { return l }
            return displayName(lhs) < displayName(rhs)
        }
    }

    var body: some View {
        List {
            if let errorText {
                Section {
                    ErrorBanner(message: errorText, retry: retry)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                LabeledContent("账号", value: account.displayName)
                LabeledContent("已关闭", value: "\(offModels.count) 个模型")
                    .foregroundStyle(offModels.isEmpty ? Color.secondary : Color.orange)
            } footer: {
                Text("关闭后该账号不再被路由到对应模型；手动开关优先于上游临时限流。")
            }

            if isLoading && models.isEmpty {
                Section {
                    LoadingSkeleton(rows: 6)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: query)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(filtered) { model in
                        row(model)
                    }
                } header: {
                    Text("模型（\(filtered.count)）")
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索模型")
        .navigationTitle("模型开关")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .toast($toast)
    }

    private func row(_ model: ModelInfo) -> some View {
        let id = modelID(model)
        let bare = bareName(id)
        return Toggle(isOn: binding(model)) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Metrics.s) {
                    Text(displayName(model))
                        .font(.callout)
                        .lineLimit(1)
                    if model.isDefault == true {
                        Text("默认")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: .capsule)
                    }
                }
                HStack(spacing: Metrics.s) {
                    Text(bare)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let ctx = model.contextLength, ctx > 0 {
                        Text("\(Fmt.compact(ctx)) ctx")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if busy.contains(id) {
                        ProgressView().controlSize(.mini)
                    }
                }
            }
        }
        .tint(theme.primary)
        .disabled(busy.contains(id))
    }

    // MARK: - 状态换算

    private func modelID(_ model: ModelInfo) -> String {
        model.modelId ?? model.name ?? ""
    }

    private func bareName(_ id: String) -> String {
        id.split(separator: ":", maxSplits: 1).last.map(String.init) ?? id
    }

    private func displayName(_ model: ModelInfo) -> String {
        if let name = model.name, !name.isEmpty { return name }
        return bareName(modelID(model))
    }

    /// 开 = 未被手动关闭。
    private func binding(_ model: ModelInfo) -> Binding<Bool> {
        let bare = bareName(modelID(model))
        return Binding(
            get: { !offModels.contains(bare) },
            set: { newValue in
                set(model, off: !newValue)
            }
        )
    }

    // MARK: - 动作

    private func load() async {
        guard let client = session.client() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await client.models()
            models = response.models
            let overview = try await client.overview()
            if let fresh = overview.accounts.first(where: { $0.uid == account.uid }) {
                offModels = Set((fresh.modelOff ?? []).compactMap(\.model))
            } else {
                offModels = Set((account.modelOff ?? []).compactMap(\.model))
            }
            errorText = nil
        } catch {
            guard !error.isCancellation else { return }
            errorText = error.humanMessage
            offModels = Set((account.modelOff ?? []).compactMap(\.model))
        }
    }

    private func set(_ model: ModelInfo, off: Bool) {
        let id = modelID(model)
        let bare = bareName(id)
        guard !id.isEmpty, !busy.contains(id) else { return }
        let previous = offModels
        busy.insert(id)
        if off {
            offModels.insert(bare)
        } else {
            offModels.remove(bare)
        }
        Task {
            defer { busy.remove(id) }
            guard let client = session.client() else {
                offModels = previous
                return
            }
            do {
                _ = try await client.setModelOff(uid: account.uid, model: id, off: off)
                toast = Toast(kind: .success, text: off ? "已关闭 \(displayName(model))" : "已开启 \(displayName(model))")
            } catch {
                offModels = previous
                toast = Toast(kind: .failure, text: error.humanMessage)
            }
        }
    }

    private func retry() {
        errorText = nil
        Task { await load() }
    }
}
