import SwiftUI

/// 队列状态卡：只把「还没跑完的项」叫排队，完成后显示已处理数。
struct QueueStatusCard: View {
    @Environment(\.appTheme) private var theme

    let queue: TaskQueue?

    private var running: Bool { queue?.isRunning ?? false }
    private var total: Int { queue?.totalCount ?? 0 }
    private var processed: Int { queue?.processedCount ?? 0 }
    private var remaining: Int { queue?.remainingCount ?? 0 }
    private var failed: Int { queue?.failedCount ?? 0 }
    private var finished: Bool { queue?.isFinished ?? false }

    private var stateText: String { queue?.stateText ?? "空闲" }

    private var stateIcon: String {
        if running { return "bolt.fill" }
        if finished { return failed > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill" }
        return "pause.fill"
    }

    private var stateTint: Color {
        if running { return theme.primary }
        if finished { return failed > 0 ? .orange : .green }
        return .secondary
    }

    /// 运行中看剩余，结束后看已处理，未开始时看排队。
    private var primaryCount: Int {
        finished ? processed : remaining
    }

    private var primaryLabel: String {
        if running { return "项待处理" }
        if finished { return "项已处理" }
        return "项排队"
    }

    private var detailText: String {
        if running {
            var text = "已处理 \(processed)/\(total)"
            if failed > 0 { text += " · 失败 \(failed)" }
            return text
        }
        if finished {
            var parts: [String] = []
            if let done = queue?.doneCount, done > 0 { parts.append("完成 \(done)") }
            if let skipped = queue?.skippedCount, skipped > 0 { parts.append("跳过 \(skipped)") }
            if failed > 0 { parts.append("失败 \(failed)") }
            return parts.isEmpty ? "全部处理完成" : parts.joined(separator: " · ")
        }
        return total > 0 ? "等待开始" : "队列为空"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.m) {
            HStack(alignment: .center, spacing: Metrics.s) {
                Text("任务队列")
                    .font(.headline)
                Spacer(minLength: Metrics.xs)
                StatusTag(text: stateText, systemImage: stateIcon, tint: stateTint)
                    .symbolEffect(.pulse, options: .repeating, isActive: running)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.s) {
                    Text(primaryCount, format: .number)
                        .font(.metric())
                        .foregroundStyle(finished ? stateTint : (running ? theme.primary : .primary))
                        .contentTransition(.numericText())
                    Text(primaryLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(spacing: Metrics.s) {
                LabeledContent("并发数") {
                    Text(concurrencyText)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("开始时间") {
                    Text(startedText)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .motion(Motion.numeric, value: primaryCount)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("任务队列\(stateText)，\(primaryCount)\(primaryLabel)，\(detailText)")
    }

    private var concurrencyText: String {
        guard let concurrency = queue?.conc, concurrency > 0 else { return "—" }
        return "\(concurrency)"
    }

    /// 后端空值时间是 `0001-01-01T00:00:00Z`，不展示。
    private var startedText: String {
        guard
            let startedAt = queue?.startedAt,
            let date = Fmt.parse(startedAt),
            Calendar.current.component(.year, from: date) > 2001
        else {
            return "—"
        }
        return Fmt.ago(startedAt)
    }
}

#Preview {
    VStack(spacing: Metrics.m) {
        QueueStatusCard(queue: TaskQueue(
            conc: 1,
            items: [
                .object(["status": .string("done")]),
                .object(["status": .string("running")])
            ],
            running: true,
            seq: 1,
            started: true,
            startedAt: nil,
            total: 3
        ))
        QueueStatusCard(queue: nil)
    }
    .padding()
}
