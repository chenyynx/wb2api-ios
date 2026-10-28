import SwiftUI

/// 设置：服务器地址、访问密钥、连接测试、关于与退出登录。
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.appTheme) private var theme
    @AppStorage(AppTheme.storageKey) private var accentName = AccentChoice.violet.rawValue

    @State private var keyDraft = ""
    @State private var isTesting = false
    @State private var testMessage: String?
    @State private var testPassed = false
    @State private var isConfirmingSignOut = false
    @State private var toast: Toast?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        @Bindable var session = session

        Form {
            Section {
                TextField("https://…", text: $session.baseURLString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()

                LabeledContent("当前地址", value: session.baseURLString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("服务器")
            } footer: {
                Text("支持自建面板地址；不带协议时自动补 https://。")
            }

            Section {
                SecureField("api_key", text: $keyDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("保存密钥", systemImage: "key.fill", action: saveKey)
                    .disabled(!canSaveKey)
            } header: {
                Text("访问密钥")
            } footer: {
                Text("密钥只写入本机 Keychain，不会参与配置同步。")
            }

            Section {
                Button(action: testConnection) {
                    HStack {
                        Label("测试连接", systemImage: "bolt.horizontal.circle")
                        Spacer(minLength: Metrics.s)
                        if isTesting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isTesting)

                if let testMessage {
                    Label(testMessage, systemImage: testPassed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.footnote)
                        .foregroundStyle(testPassed ? Color.green : Color.red)
                        .symbolEffect(.bounce, value: testPassed)
                }
            } header: {
                Text("诊断")
            } footer: {
                Text("调用 panel/api/overview 验证地址与密钥是否可用。")
            }

            Section {
                AccentPickerRow(selection: $accentName)
            } header: {
                Text("外观")
            } footer: {
                Text("强调色会应用到按钮、图表、高亮与渐变，切换后立即生效。")
            }

            Section {
                LabeledContent("版本", value: appVersion)
                LabeledContent("构建", value: buildNumber)
                LabeledContent("系统要求", value: "iOS 26")
                LabeledContent("设计", value: "Liquid Glass · \(theme.accent.title)强调")
            } header: {
                Text("关于")
            } footer: {
                Text("WorkBuddy2API · 账号池运维面板")
            }

            Section {
                Button("退出登录", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive, action: askSignOut)
            } footer: {
                Text("退出后需要重新填写 api_key 才能访问面板。")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "退出登录？",
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive, action: signOut)
            Button("取消", role: .cancel, action: dismissSignOutPrompt)
        } message: {
            Text("本机保存的 api_key 将被删除。")
        }
        .task { loadKeyDraft() }
        .toast($toast)
    }

    // MARK: - 状态

    private var canSaveKey: Bool {
        let trimmed = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != session.apiKey
    }

    // MARK: - 动作

    private func loadKeyDraft() {
        keyDraft = session.apiKey
    }

    private func saveKey() {
        session.update(apiKey: keyDraft)
        toast = Toast(kind: .success, text: "密钥已保存")
    }

    private func testConnection() {
        Task { await performTest() }
    }

    private func performTest() async {
        guard let client = session.client() else {
            testPassed = false
            testMessage = "请先填写服务器地址"
            return
        }
        isTesting = true
        defer { isTesting = false }
        do {
            let overview = try await client.overview()
            testPassed = true
            testMessage = "连接正常 · \(overview.accounts.count) 个账号"
        } catch {
            testPassed = false
            testMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func askSignOut() {
        isConfirmingSignOut = true
    }

    private func dismissSignOutPrompt() {
        isConfirmingSignOut = false
    }

    private func signOut() {
        session.signOut()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(SessionStore())
}
