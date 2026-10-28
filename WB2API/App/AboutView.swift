import SwiftUI

/// 「开源」页：仓库信息、构建指引与反馈渠道。
struct AboutView: View {
    @Environment(\.appTheme) private var theme

    private let repoURL = URL(string: "https://github.com/chenyynx/wb2api-ios")!
    private let issuesURL = URL(string: "https://github.com/chenyynx/wb2api-ios/issues")!
    private let releasesURL = URL(string: "https://github.com/chenyynx/wb2api-ios/releases")!
    private let actionsURL = URL(string: "https://github.com/chenyynx/wb2api-ios/actions")!
    private let backendURL = URL(string: "https://github.com/misakano7545/workbuddy2api-panel")!

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Metrics.xs) {
                    Text("Work")
                        .font(.title3.bold())
                    Text("WorkBuddy2API 面板的 iOS 原生客户端。SwiftUI 零第三方依赖，iOS 26 Liquid Glass。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Metrics.xs)

                LabeledContent("版本", value: "\(version) (\(build))")
                LabeledContent("许可", value: "MIT")
            } header: {
                Text("关于")
            }

            Section {
                linkRow("GitHub 仓库", subtitle: "源码 · README · 构建说明", icon: "curlybraces.square.fill", url: repoURL)
                linkRow("下载安装包", subtitle: "CI 产出的未签名 IPA，重签安装", icon: "arrow.down.circle.fill", url: releasesURL)
                linkRow("问题反馈", subtitle: "Bug 与功能建议请提 Issue", icon: "exclamationmark.bubble.fill", url: issuesURL)
                linkRow("构建状态", subtitle: "双 job：模拟器单测 + 无签名 IPA", icon: "checkmark.seal.fill", url: actionsURL)
            } header: {
                Text("开源")
            } footer: {
                Text("本 App 是客户端，账号池网关与面板本体是独立的开源项目。")
            }

            Section {
                linkRow("workbuddy2api-panel", subtitle: "后端面板 · Go · 账号池网关", icon: "server.rack", url: backendURL)
            } header: {
                Text("后端项目")
            }

            Section {
                VStack(alignment: .leading, spacing: Metrics.s) {
                    Label("从源码构建", systemImage: "hammer.fill")
                        .font(.callout.bold())
                    Text("工程由 XcodeGen 生成：")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("brew install xcodegen\nxcodegen generate\nopen WB2API.xcodeproj")
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(Metrics.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: Metrics.radiusS))
                    Text("需要 Xcode 26+；`xcodebuild test` 可直接跑 40+ 单元测试。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, Metrics.xs)
            } header: {
                Text("构建")
            } footer: {
                Text("图标：Phosphor Icons（MIT）。api_key 只存本机 Keychain；App 不做任何统计或上报。")
            }
        }
        .navigationTitle("开源")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func linkRow(_ title: String, subtitle: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: Metrics.m) {
                Image(systemName: icon)
                    .foregroundStyle(theme.primary)
                    .frame(width: Metrics.l)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Metrics.s)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, Metrics.xs)
            .frame(minHeight: Metrics.minTap)
        }
        .accessibilityLabel("\(title)，打开外部链接")
    }
}

#Preview {
    NavigationStack { AboutView() }
}
