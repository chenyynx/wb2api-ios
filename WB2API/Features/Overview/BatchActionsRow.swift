import SwiftUI

/// 批量操作：整卡一张玻璃面板，内部四列图标按钮（不再各自一块玻璃）。
struct BatchActionsRow: View {
    @Environment(\.appTheme) private var theme

    let running: BatchAction?
    let onRun: (BatchAction) -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Metrics.s),
        count: 4
    )

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            SectionHeader(title: "批量操作", subtitle: subtitle)

            LazyVGrid(columns: columns, spacing: Metrics.s) {
                ForEach(BatchAction.allCases) { action in
                    batchButton(action)
                }
            }
            .padding(.vertical, Metrics.m)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Metrics.radiusL))
        }
    }

    private func batchButton(_ action: BatchAction) -> some View {
        Button {
            onRun(action)
        } label: {
            VStack(spacing: Metrics.xs) {
                if running == action {
                    ProgressView()
                        .controlSize(.small)
                        .frame(height: 22)
                } else {
                    Image(systemName: action.icon)
                        .font(.title3)
                        .foregroundStyle(theme.primary)
                        .frame(height: 22)
                        .symbolEffect(.bounce, value: running)
                }

                Text(action.shortTitle)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(running != nil)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.hint)
    }

    private var subtitle: String {
        guard let running else { return "一次对全部账号生效" }
        return "\(running.title)执行中…"
    }
}
