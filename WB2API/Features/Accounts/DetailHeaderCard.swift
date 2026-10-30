import SwiftUI

/// 详情头：头像、昵称、状态标签与关键信息。
struct DetailHeaderCard: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            HStack(alignment: .center, spacing: Metrics.m) {
                AccountAvatar(account: account, size: 54)

                VStack(alignment: .leading, spacing: Metrics.xs) {
                    Text(account.displayName)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: Metrics.s) {
                        StatusTag(
                            text: AccountStatusStyle.text(for: account),
                            systemImage: AccountStatusStyle.icon(for: account),
                            tint: AccountStatusStyle.tint(for: account)
                        )

                        Text(account.realmLabel)
                            .font(.tag)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: Metrics.s) {
                DetailRow("UID", systemImage: "number", value: shortUID)
                DetailRow("最后活跃", systemImage: "clock", value: Fmt.ago(account.lastSuccess))
                DetailRow("累计成功", systemImage: "checkmark.circle", value: "\(Fmt.compact(account.successCount)) 次")
            }

            if account.isDisabled {
                Label("已禁用，不参与调度", systemImage: "nosign")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if account.isPaused {
                Label("已暂停选号，仍参与签到 / 保活", systemImage: "pause.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.blue)
            }

            if account.isCooling, let until = account.until, let left = Fmt.countdown(until: until) {
                Label("冷却中 · \(left)后恢复", systemImage: "hourglass")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let expiryWarning {
                Label(expiryWarning, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let checkinDone = account.checkinDone {
                if checkinDone {
                    Label("今日已签到", systemImage: "checkmark.seal.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                } else {
                    Label("今日未签到", systemImage: "seal")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
        .motion(Motion.spring, value: AccountStatusStyle.text(for: account))
    }

    private var shortUID: String {
        String(account.uid.prefix(8))
    }

    /// 只有 3 天内到期才提醒，避免长期挂着一条无意义的警告。
    private var expiryWarning: String? {
        guard let raw = account.creditsEarliestExpiry, let date = Fmt.parse(raw) else { return nil }
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return "最早一笔积分已过期" }
        let days = Int(ceil(seconds / 86_400))
        return days <= 3 ? "最早一笔积分 \(days) 天后到期" : nil
    }
}
