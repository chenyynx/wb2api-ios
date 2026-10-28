import SwiftUI

/// 扫描结果：按账号分组，可逐账号 / 逐任务勾选，单独执行或批量执行。
struct ScanResultView: View {
    @Environment(\.appTheme) private var theme

    let tasks: [AccountTask]
    let selected: Set<String>
    let running: [String: TaskRunState]
    let busyTaskID: String?
    var onToggleTask: (AccountTask) -> Void
    var onToggleGroup: ([AccountTask], Bool) -> Void
    var onRunOne: (AccountTask) -> Void
    var onAction: (AccountTask, TaskAction) -> Void

    @State private var expandedUID: String?

    private var groups: [TaskGroup] {
        let dict = Dictionary(grouping: tasks, by: \.uid)
        return dict.keys.sorted().compactMap { uid in
            guard let items = dict[uid], let first = items.first else { return nil }
            return TaskGroup(
                uid: uid,
                nickname: first.nickname.isEmpty ? String(uid.prefix(8)) : first.nickname,
                tasks: items.sorted { $0.id < $1.id }
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            SectionHeader(
                title: "扫描结果",
                subtitle: tasks.isEmpty ? "点「扫描全部」拉取待办" : "\(tasks.count) 项 · 勾选后批量执行"
            )

            if tasks.isEmpty {
                ContentUnavailableView(
                    "没有待办任务",
                    systemImage: "checkmark.seal",
                    description: Text("先点「扫描全部」，或所有账号的任务都已处理完")
                )
                .glassCard()
            } else {
                ForEach(groups) { group in
                    groupCard(group)
                }
            }
        }
    }

    private func groupCard(_ group: TaskGroup) -> some View {
        let chosen = group.tasks.filter { selected.contains($0.id) }.count
        let allChosen = chosen == group.tasks.count && !group.tasks.isEmpty
        let expanded = expandedUID == group.uid

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Metrics.s) {
                Button {
                    onToggleGroup(group.tasks, !allChosen)
                } label: {
                    Image(systemName: allChosen ? "checkmark.circle.fill" : (chosen > 0 ? "minus.circle.fill" : "circle"))
                        .font(.title3)
                        .foregroundStyle(chosen > 0 ? theme.primary : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(allChosen ? "取消选择 \(group.nickname)" : "选择 \(group.nickname) 的全部任务")

                Button {
                    withAnimation(.snappy) { expandedUID = expanded ? nil : group.uid }
                } label: {
                    HStack(spacing: Metrics.s) {
                        Label(group.nickname, systemImage: "person.crop.circle")
                            .font(.callout.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(chosen > 0 ? "已选 \(chosen)/\(group.tasks.count)" : "\(group.tasks.count) 项")
                            .font(.caption)
                            .foregroundStyle(chosen > 0 ? theme.primary : Color.secondary)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(Metrics.m)

            if expanded {
                VStack(spacing: Metrics.s) {
                    ForEach(group.tasks) { task in
                        TaskRow(
                            task: task,
                            isSelected: selected.contains(task.id),
                            state: running[task.id],
                            isBusy: busyTaskID == task.id,
                            onToggle: { onToggleTask(task) },
                            onRun: { onRunOne(task) },
                            onAction: { onAction(task, $0) }
                        )
                    }
                }
                .padding([.horizontal, .bottom], Metrics.m)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassCard(padding: 0, cornerRadius: Metrics.radiusM)
    }
}

private struct TaskGroup: Identifiable {
    let uid: String
    let nickname: String
    let tasks: [AccountTask]
    var id: String { uid }
}

// MARK: - 单行

enum TaskAction: String {
    case accept = "接受"
    case claim = "领取"
}

private struct TaskRow: View {
    @Environment(\.appTheme) private var theme

    let task: AccountTask
    let isSelected: Bool
    let state: TaskRunState?
    let isBusy: Bool
    var onToggle: () -> Void
    var onRun: () -> Void
    var onAction: (TaskAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.xs) {
            HStack(alignment: .top, spacing: Metrics.s) {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? theme.primary : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "取消选择 \(task.title)" : "选择 \(task.title)")

                VStack(alignment: .leading, spacing: Metrics.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: Metrics.s) {
                        Text(task.title)
                            .font(.callout)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        StatusTag(text: task.statusText, systemImage: "circle.fill", tint: task.statusTint(for: theme))
                    }

                    if let progress = task.progressText {
                        ProgressView(value: task.target.map { Double(min(task.current ?? 0, $0)) / Double($0) } ?? 0)
                            .tint(theme.primary)
                        Text("进度 \(progress)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let state {
                        runStateLine(state)
                    }
                }
            }

            HStack {
                if let credit = task.credit, credit > 0 {
                    Label("+\(credit)", systemImage: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                if task.canClaim {
                    Button(TaskAction.claim.rawValue) { onAction(.claim) }
                        .font(.footnote.bold())
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                        .disabled(isBusy || isRunningState)
                }
                if task.canAccept {
                    Button(TaskAction.accept.rawValue) { onAction(.accept) }
                        .font(.footnote.bold())
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .disabled(isBusy || isRunningState)
                }
                Button {
                    onRun()
                } label: {
                    if isRunningState {
                        ProgressView().controlSize(.mini)
                    } else {
                        Label("执行", systemImage: "play.fill")
                    }
                }
                .font(.footnote.bold())
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(isBusy || isRunningState)
            }
        }
        .padding(Metrics.s)
        .background(isSelected ? theme.primary.opacity(0.08) : Color.clear, in: .rect(cornerRadius: Metrics.radiusS))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.radiusS)
                .strokeBorder(isSelected ? theme.primary.opacity(0.35) : .clear, lineWidth: 1)
        }
        .animation(.snappy, value: task.acceptStatus)
        .animation(.snappy, value: isSelected)
    }

    private var isRunningState: Bool {
        if case .running = state { return true }
        return false
    }

    @ViewBuilder
    private func runStateLine(_ state: TaskRunState) -> some View {
        switch state {
        case .running:
            Label("执行中…", systemImage: "hourglass")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .success(let text):
            Label(text, systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
                .lineLimit(2)
        case .failure(let text):
            Label(text, systemImage: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
        case .cancelled:
            EmptyView()
        }
    }
}
