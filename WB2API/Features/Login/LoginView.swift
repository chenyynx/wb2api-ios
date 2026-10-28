import SwiftUI

/// 登录：选区域 → 生成授权链接 → 每 3 秒轮询结果（5 分钟超时）。
///
/// 轮询用 `.task(id:)` 绑定授权 state：换链接、离开页面都会自动取消旧循环。
struct LoginView: View {
    @Environment(\.appTheme) private var theme

    @Environment(SessionStore.self) private var session

    /// 登录域：国内版 cn / 国际版 global
    @State private var realm = "cn"
    @State private var startResponse: LoginStartResponse?
    @State private var pollResult: LoginPollResponse?
    @State private var isStarting = false
    @State private var errorText: String?
    @State private var pollNote: String?
    @State private var timedOut = false

    // API Key 直加（面板 /accounts/add_apikey）
    @State private var apiKeyInput = ""
    @State private var apiKeyNickname = ""
    @State private var isAddingKey = false
    @State private var keyMessage: String?
    @State private var keyMessageIsError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.l) {
                VStack(alignment: .leading, spacing: Metrics.m) {
                    SectionHeader(title: "登录区域", subtitle: "选择账号所属版本，授权页会跳到对应站点")

                    Picker("登录区域", selection: $realm) {
                        Text("国内版").tag("cn")
                        Text("国际版").tag("global")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("登录区域")

                    Label(
                        realm == "cn" ? "跳转 copilot.tencent.com 登录" : "跳转 workbuddy.ai 登录",
                        systemImage: realm == "cn" ? "building.2" : "globe.asia.australia"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()

                Button(action: start) {
                    Group {
                        if isStarting {
                            ProgressView()
                        } else {
                            Label(
                                startResponse == nil ? "生成授权链接" : "重新生成链接",
                                systemImage: "link.badge.plus"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .frame(minHeight: Metrics.minTap)
                .disabled(isStarting)

                if let startResponse, let urlString = startResponse.url, !urlString.isEmpty {
                    LoginLinkCard(realm: startResponse.realm, urlString: urlString)
                }

                if let pollResult {
                    LoginResultCard(result: pollResult)

                    Button("再登一个账号", systemImage: "person.badge.plus", action: reset)
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .frame(minHeight: Metrics.minTap)
                } else if startResponse != nil {
                    VStack(alignment: .leading, spacing: Metrics.s) {
                        HStack(spacing: Metrics.s) {
                            Image(systemName: timedOut ? "hourglass.badge.xmark" : "hourglass")
                                .foregroundStyle(timedOut ? Color.orange : theme.primary)
                                .symbolEffect(.pulse, options: .repeating, isActive: !timedOut)
                            Text(timedOut ? "授权超时" : "等待授权…")
                                .font(.headline)
                        }

                        Text(timedOut
                             ? "已等待 5 分钟仍未完成，请重新生成链接。"
                             : "每 3 秒自动检查一次，5 分钟未完成将超时。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let pollNote {
                            Text(pollNote)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }

                apiKeyCard

                if let errorText {
                    ErrorBanner(message: errorText, retry: start)
                }
            }
            .padding(Metrics.m)
        }
        .background(.background)
        .navigationTitle("登录")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: startResponse?.state) { await pollUntilDone() }
        .sensoryFeedback(.success, trigger: pollResult?.uid)
    }

    // MARK: - API Key 直加

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            SectionHeader(title: "用 API Key 添加", subtitle: "ck_ / pt_ 开头的静态 Key，后端会先探测额度")

            SecureField("ck_… 或 pt_…", text: $apiKeyInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.callout.monospaced())
                .padding(Metrics.s)
                .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: Metrics.radiusS))
                .accessibilityLabel("API Key")

            TextField("昵称（可选）", text: $apiKeyNickname)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.callout)
                .padding(Metrics.s)
                .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: Metrics.radiusS))

            Button(action: addAPIKey) {
                Group {
                    if isAddingKey {
                        ProgressView()
                    } else {
                        Label("添加账号", systemImage: "key.fill")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingKey)

            if let keyMessage {
                Label(keyMessage, systemImage: keyMessageIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(keyMessageIsError ? Color.red : Color.green)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func addAPIKey() {
        Task {
            guard let client = session.client() else { return }
            isAddingKey = true
            defer { isAddingKey = false }
            let token = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let nickname = apiKeyNickname.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                let raw = try await client.addAPIKey(
                    accessToken: token,
                    nickname: nickname.isEmpty ? nil : nickname,
                    uid: nil
                )
                let outcome = ActionOutcome(raw)
                guard outcome.ok else {
                    keyMessage = outcome.message ?? "添加失败"
                    keyMessageIsError = true
                    return
                }
                let name = raw.objectValue?["nickname"]?.stringValue
                    ?? raw.objectValue?["uid"]?.stringValue
                    ?? "账号"
                keyMessage = "已添加 \(name)"
                keyMessageIsError = false
                apiKeyInput = ""
                apiKeyNickname = ""
            } catch {
                keyMessage = error.humanMessage
                keyMessageIsError = true
            }
        }
    }

    // MARK: - 发起登录

    private func start() {
        Task { await performStart() }
    }

    private func performStart() async {
        guard let client = session.client() else { return }
        isStarting = true
        errorText = nil
        pollNote = nil
        timedOut = false
        pollResult = nil
        startResponse = nil
        defer { isStarting = false }

        do {
            startResponse = try await client.loginStart(realm: realm)
        } catch {
            errorText = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func reset() {
        startResponse = nil
        pollResult = nil
        errorText = nil
        pollNote = nil
        timedOut = false
    }

    // MARK: - 轮询

    private func pollUntilDone() async {
        guard let state = startResponse?.state, !state.isEmpty, pollResult == nil else { return }
        let deadline = Date.now.addingTimeInterval(300)

        while Date.now < deadline {
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
            if Task.isCancelled || pollResult != nil { return }
            await pollOnce(state: state)
            if pollResult != nil { return }
        }

        if !Task.isCancelled {
            timedOut = true
        }
    }

    private func pollOnce(state: String) async {
        guard let client = session.client() else { return }
        do {
            let response = try await client.loginPoll(state: state)
            if response.done == true {
                pollResult = response
                pollNote = nil
                timedOut = false
            }
        } catch {
            // 单次检查失败不终止整个流程，把原因留在状态卡里。
            pollNote = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environment(SessionStore())
}
