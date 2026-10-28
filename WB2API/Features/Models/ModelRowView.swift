import SwiftUI

/// 模型行：ID、倍率、上下文长度，默认/繁忙用语义标签。
struct ModelRowView: View {
    @Environment(\.appTheme) private var theme

    let model: ModelInfo

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Metrics.s) {
                Text(model.displayID)
                    .font(.callout.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                if model.isDefault == true {
                    StatusTag(text: "默认", systemImage: "star.fill", tint: theme.primary)
                }
                if model.isBusy {
                    StatusTag(text: "繁忙", systemImage: "hourglass", tint: .orange)
                        .symbolEffect(.pulse, options: .repeating, isActive: model.isBusy)
                }
            }

            if let description = model.description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: Metrics.m) {
                Label("倍率 \(model.creditMultiplierText)", systemImage: "creditcard")
                Label("上下文 \(model.contextText)", systemImage: "ruler")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, Metrics.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        ModelRowView(model: ModelInfo(
            modelId: "cn:glm-5.2",
            name: "账号1",
            credits: "x0.79",
            contextLength: 1_000_000,
            description: "1M 上下文，擅长长程任务",
            supportsImages: true,
            supportsReasoning: true,
            supportsToolCall: true,
            isDefault: true,
            maxOutputTokens: 64_000,
            defaultEffort: "high",
            onlyReasoning: true,
            busy: "busy"
        ))
    }
}
