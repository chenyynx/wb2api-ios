import SwiftUI

/// 积分卡：剩余 / 总额、水位条、最早到期与近期到期明细。
struct CreditsCard: View {
    @Environment(\.appTheme) private var theme

    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("积分")
                    .font(.tag)
                    .foregroundStyle(.secondary)

                Spacer(minLength: Metrics.s)

                Text(Fmt.percent(account.creditProgress, digits: 0))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: Metrics.xs) {
                Text(Fmt.credits(account.credits))
                    .font(.metric(.largeTitle))
                    .foregroundStyle(theme.primary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Text("/ \(Fmt.credits(account.creditsTotal))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            CreditBar(progress: account.creditProgress)

            Divider()

            DetailRow("最早到期", systemImage: "calendar", value: expiryText)

            ForEach(Array(buckets.indices), id: \.self) { index in
                HStack(spacing: Metrics.s) {
                    Text(Fmt.day(buckets[index].date ?? buckets[index].expiresAt))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: Metrics.s)

                    Text("\(Fmt.credits(buckets[index].remain)) 积分")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
        .motion(Motion.numeric, value: account.credits)
    }

    private var buckets: [ExpiryBucket] {
        Array((account.creditsExpiryBuckets ?? []).prefix(3))
    }

    private var expiryText: String {
        guard let raw = account.creditsEarliestExpiry else { return "—" }
        let day = Fmt.day(raw)
        guard let remain = account.creditsEarliestRemaining else { return day }
        return "\(day) · \(Fmt.credits(remain))"
    }
}
