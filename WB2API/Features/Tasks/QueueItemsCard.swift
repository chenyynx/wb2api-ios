import SwiftUI

/// 队列明细：当前队列里每一项跑到哪了。
///
/// 后端 `tasks/queue` 的 `items` 是 `{uid,nickname,kind,code,title,status,message}`。
/// 之前只显示汇总数字，用户看不出卡在哪一项、为什么跳过。
struct QueueItemsCard: View {
    @Environment(\.appTheme) private var theme

    let items: [JSONValue]

    private var lines: [QueueLine] {
        items.enumerated().compactMap { index, value in QueueLine(index: index, value: value) }
    }

    private var doneCount: Int {
        lines.filter { $0.status == "done" || $0.status == "skipped" }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            SectionHeader(
                title: "队列明细",
                subtitle: lines.isEmpty ? "队列为空" : "\(doneCount)/\(lines.count) 已处理"
            )

            if lines.isEmpty {
                ContentUnavailableView(
                    "队列为空",
                    systemImage: "list.bullet",
                    description: Text("点「扫描全部」后再执行，队列明细会出现在这里")
                )
                .padding(.vertical, Metrics.m)
                .glassCard()
            } else {
                VStack(spacing: Metrics.xs) {
                    ForEach(lines.prefix(12)) { line in
                        row(line)
                    }
                    if lines.count > 12 {
                        Text("还有 \(lines.count - 12) 项…")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(Metrics.s)
                .glassCard(padding: 0, cornerRadius: Metrics.radiusM)
            }
        }
    }

    private func row(_ line: QueueLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.s) {
            Circle()
                .fill(line.tint(for: theme))
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                    .font(.footnote)
                    .lineLimit(1)
                HStack(spacing: Metrics.s) {
                    Text(line.owner)
                    Text(line.statusText)
                    if let message = line.message, !message.isEmpty {
                        Text(message)
                            .lineLimit(1)
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Metrics.xs)
        .accessibilityElement(children: .combine)
    }
}

/// 单条队列项。
struct QueueLine: Identifiable {
    let id: Int
    let title: String
    let owner: String
    let status: String
    let message: String?

    init?(index: Int, value: JSONValue) {
        guard let obj = value.objectValue else { return nil }
        let code = obj["code"]?.stringValue ?? ""
        let title = obj["title"]?.stringValue ?? code
        guard !title.isEmpty else { return nil }
        id = index
        self.title = title
        owner = obj["nickname"]?.stringValue ?? String((obj["uid"]?.stringValue ?? "").prefix(8))
        status = obj["status"]?.stringValue ?? "pending"
        message = obj["message"]?.stringValue
    }

    var statusText: String {
        switch status {
        case "done": return "完成"
        case "running": return "执行中"
        case "skipped": return "跳过"
        case "error", "failed": return "失败"
        default: return "排队中"
        }
    }

    func tint(for theme: AppTheme) -> Color {
        switch status {
        case "done": return .green
        case "running": return theme.primary
        case "skipped": return .secondary
        case "error", "failed": return .red
        default: return .orange
        }
    }
}
