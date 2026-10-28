import SwiftUI

/// 模型详情头卡：ID、描述、状态标签与计费倍率。
struct ModelDetailHeaderCard: View {
    @Environment(\.appTheme) private var theme

    let model: ModelInfo

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            Text(model.displayID)
                .font(.title2.bold())
                .textSelection(.enabled)

            if let description = model.description, !description.isEmpty {
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Metrics.xs) {
                if model.isDefault == true {
                    StatusTag(text: "默认模型", systemImage: "star.fill", tint: theme.primary)
                }
                StatusTag(
                    text: model.busyLabel,
                    systemImage: model.isBusy ? "hourglass" : "checkmark.seal",
                    tint: model.isBusy ? .orange : .green
                )
                .symbolEffect(.pulse, options: .repeating, isActive: model.isBusy)
            }
            .padding(.top, Metrics.xs)

            HStack(alignment: .firstTextBaseline, spacing: Metrics.s) {
                Text(model.creditMultiplierText)
                    .font(.metric())
                    .foregroundStyle(theme.primary)
                    .contentTransition(.numericText())
                Text("倍率")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.top, Metrics.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .motion(Motion.numeric, value: model.creditMultiplier)
    }
}
