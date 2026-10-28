import SwiftUI

/// 队列操作：执行队列（主）+ 扫描全部（次）+ 暂停（运行中时替代执行按钮）。
struct QueueActionsRow: View {
    @Environment(\.appTheme) private var theme

    let isScanning: Bool
    let isRunning: Bool
    var onScan: () -> Void
    var onRun: () -> Void
    var onPause: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            if isRunning {
                Button(action: onPause) {
                    QueueActionLabel(
                        title: "暂停队列",
                        systemImage: "pause.fill",
                        isBusy: false
                    )
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
            } else {
                Button(action: onRun) {
                    QueueActionLabel(
                        title: "执行队列",
                        systemImage: "play.fill",
                        isBusy: false
                    )
                }
                .buttonStyle(.glassProminent)
                .tint(theme.primary)
                .disabled(isScanning)
            }

            Button(action: onScan) {
                QueueActionLabel(
                    title: isScanning ? "正在扫描…" : "扫描全部",
                    systemImage: "magnifyingglass",
                    isBusy: isScanning
                )
            }
            .buttonStyle(.glass)
            .disabled(isScanning || isRunning)

            if isRunning {
                Label("暂停后当前任务会跑完，其余任务不再执行。", systemImage: "pause.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.top, Metrics.xs)
            } else {
                Label("扫描会刷新所有账号的任务；执行会按队列并发拉取。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, Metrics.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: isRunning)
    }
}
