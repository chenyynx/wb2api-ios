import SwiftUI

/// 配置：网页端同款中文分区 + 未映射键的原始表单 + 高级 JSON 编辑。
struct ConfigView: View {
    @Environment(SessionStore.self) private var session
    @State private var editor = ConfigEditor()
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var isSaving = false
    @State private var isJSONPresented = false
    @State private var toast: Toast?

    var body: some View {
        Form {
            if let errorText {
                Section {
                    ErrorBanner(message: errorText, retry: retry)
                }
            }

            if isLoading && !editor.isLoaded {
                Section {
                    LoadingSkeleton(rows: 6)
                }
            } else if !editor.isLoaded {
                ContentUnavailableView {
                    Label("配置未加载", systemImage: "slider.horizontal.3")
                } description: {
                    Text("下拉刷新重新获取面板配置。")
                }
            } else {
                Section {
                    LabeledContent("配置文件", value: editor.path ?? "—")
                    LabeledContent("字段数", value: "\(editor.topLevelKeys.count) 组")
                    if editor.apiKeyEnvManaged {
                        Label("api_key 由环境变量托管", systemImage: "lock.shield")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("概览")
                } footer: {
                    if editor.hasInvalidFields {
                        Label(invalidFieldSummary, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                ForEach(ConfigSchema.sections) { section in
                    Section {
                        ForEach(section.fields) { spec in
                            ConfigFieldRow(
                                spec: spec,
                                value: editor.value(at: spec.path),
                                onChange: { newValue in
                                    editor.setValue(newValue, at: spec.path)
                                },
                                onValidityChange: { isValid in
                                    editor.setInvalid(spec.id, !isValid)
                                }
                            )
                            .disabled(spec.id == "api_key" && editor.apiKeyEnvManaged)
                        }
                    } header: {
                        Text(section.title)
                    } footer: {
                        if let footer = section.footer {
                            Text(footer)
                        }
                    }
                }

                if !otherGroups.isEmpty {
                    Section {
                        NavigationLink {
                            OtherConfigView(editor: editor)
                        } label: {
                            LabeledContent("其他原始配置", value: "\(otherGroups.count) 组")
                        }
                    } footer: {
                        Text("网页端未做中文映射的键保留在这里，不会丢配置。")
                    }
                }

                Section {
                    Button("高级 JSON 编辑", systemImage: "curlybraces", action: presentJSON)
                    Button("还原改动", systemImage: "arrow.uturn.backward", action: revert)
                        .disabled(!editor.isDirty)
                } footer: {
                    Text("数组、嵌套对象等复杂字段请在高级 JSON 编辑中修改。")
                }
            }
        }
        .navigationTitle("配置")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSaving {
                    ProgressView()
                        .accessibilityLabel("正在保存")
                } else {
                    Button("保存", action: save)
                        .disabled(!editor.isDirty || editor.hasInvalidFields)
                }
            }
        }
        .sheet(isPresented: $isJSONPresented) {
            AdvancedJSONView(editor: editor)
        }
        .toast($toast)
    }

    // MARK: - 派生

    private var otherGroups: [ConfigGroup] {
        editor.uncuratedGroups(excluding: ConfigSchema.curatedPaths)
    }

    private var invalidFieldSummary: String {
        let labels = editor.invalidFieldIDs
            .compactMap { ConfigSchema.label(forFieldID: $0) }
            .sorted()
        guard !labels.isEmpty else { return "有字段格式不正确，修正后才能保存" }
        return "格式不正确：\(labels.joined(separator: "、"))"
    }

    /// 已有密钥却被清空 = 会把网关改成无鉴权公开服务，直接拦住。
    private var wouldDisableAuth: Bool {
        let old = editor.original.objectValue?["api_key"]?.stringValue ?? ""
        let new = editor.value(at: ["api_key"]).stringValue ?? ""
        return !old.isEmpty && new.isEmpty
    }

    // MARK: - 动作

    private func load() async {
        guard let client = session.client() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await client.config()
            editor.load(response)
            errorText = nil
        } catch {
            errorText = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func retry() {
        Task { await load() }
    }

    private func save() {
        Task { await performSave() }
    }

    private func performSave() async {
        guard let client = session.client() else { return }
        guard !editor.hasInvalidFields else {
            toast = Toast(kind: .failure, text: "有字段格式不正确，修正后再保存")
            return
        }
        guard !wouldDisableAuth else {
            toast = Toast(kind: .failure, text: "API 密钥不能为空（清空会关闭网关鉴权）")
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let result = try await client.saveConfig(editor.draft)
            editor.markSaved()
            toast = Toast(kind: .success, text: result.summary)
            await load()
        } catch {
            toast = Toast(kind: .failure, text: error.humanMessage)
        }
    }

    private func revert() {
        editor.revert()
        toast = Toast(kind: .info, text: "已还原为加载时的配置")
    }

    private func presentJSON() {
        isJSONPresented = true
    }
}

#Preview {
    NavigationStack {
        ConfigView()
    }
    .environment(SessionStore())
}
