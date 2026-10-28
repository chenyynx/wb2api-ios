import SwiftUI

/// 登录成功卡片：展示回填的账号凭据与积分。
struct LoginResultCard: View {
    @Environment(\.appTheme) private var theme

    let result: LoginPollResponse

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            Label("登录成功", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(theme.primary)
                .symbolEffect(.bounce, value: result.uid)

            LabeledContent {
                Text(result.uid ?? "—")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            } label: {
                Text("UID")
            }

            LabeledContent("昵称", value: result.nickname ?? "—")
            LabeledContent("区域", value: realmLabel(result.realm))

            LabeledContent {
                Text(Fmt.credits(result.credits))
                    .font(.body.monospacedDigit())
                    .contentTransition(.numericText())
            } label: {
                Text("积分")
            }

            if let total = result.creditsTotal {
                LabeledContent {
                    Text(Fmt.credits(total))
                        .font(.body.monospacedDigit())
                } label: {
                    Text("积分上限")
                }
            }

            if let message = result.checkinMessage, !message.isEmpty {
                Label(message, systemImage: "calendar.badge.checkmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let balanceError = result.balanceError, !balanceError.isEmpty {
                Label(balanceError, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func realmLabel(_ realm: String?) -> String {
        switch realm {
        case "cn": "国内版"
        case "global": "国际版"
        case .some(let other): other
        case .none: "—"
        }
    }
}
