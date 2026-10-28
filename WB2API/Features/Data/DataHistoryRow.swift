import SwiftUI

/// 「数据」页里的一行二级入口：图标 + 标题 / 副标题 + 尾部箭头。
struct DataHistoryRow: View {
    @Environment(\.appTheme) private var theme

    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: Metrics.m) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(theme.primary)
                .frame(width: Metrics.l)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(Metrics.m)
        .frame(minHeight: Metrics.minTap)
        .contentShape(.rect)
    }
}
