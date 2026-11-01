import SwiftUI

/// 账号行内容：头像 + 昵称/状态 + 积分水位。
///
/// 只负责内容，玻璃底与内边距交给容器（`List` 行或概览的预览行）。
/// 警告状态（需重新登录）支持「忽略」：忽略后红色提示降级为普通次要文案，
/// 状态本身照常显示——不撒谎，只是不再反复提醒。
struct AccountRowView: View {
    let account: Account
    var isBusy: Bool = false
    /// 该账号的警告是否已被用户忽略（列表层从 IgnoredWarnings 传入）。
    var warningIgnored: Bool = false

    /// 红色警告是否要压成灰色：需重新登录 且 用户已忽略。
    private var suppressWarning: Bool {
        account.needsLogin && warningIgnored
    }

    var body: some View {
        HStack(spacing: Metrics.s + Metrics.xs) {
            AccountAvatar(account: account, size: 42, suppressWarning: suppressWarning)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(statusLine)
                    .font(.footnote)
                    .foregroundStyle(suppressWarning ? Color.secondary : (account.needsLogin ? Color.red : Color.secondary))
                    .lineLimit(1)
            }

            Spacer(minLength: Metrics.s)

            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("正在执行操作")
            } else {
                VStack(alignment: .trailing, spacing: Metrics.xs) {
                    Text(Fmt.credits(account.credits))
                        .font(.metricSmall())
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    CreditBar(progress: account.creditProgress)
                        .frame(width: 64)
                }
            }
        }
        .frame(minHeight: Metrics.minTap)
        .contentShape(Rectangle())
        .motion(Motion.numeric, value: account.credits)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var statusLine: String {
        if account.needsLogin {
            return account.isDisabled ? "需重新登录 · 登录态已失效" : "登录态异常 · 建议重新登录"
        }
        if let left = account.coolingLeft {
            return "冷却中 · \(left)后恢复"
        }
        var parts = [AccountStatusStyle.text(for: account), Fmt.ago(account.lastSuccess)]
        if account.checkinDone == false {
            parts.append("未签到")
        }
        return parts.joined(separator: " · ")
    }

    private var accessibilityText: String {
        "\(account.displayName)，\(AccountStatusStyle.text(for: account))，剩余积分 \(Fmt.credits(account.credits))"
    }
}
