import SwiftUI

/// 任务：队列状态 + 批量操作 + 扫描结果（逐账号/逐任务勾选）+ 作业列表。
struct TasksView: View {
    @Environment(SessionStore.self) private var session

    @State private var queue = Loader<TaskQueue>()
    @State private var jobs = Loader<JSONValue>()
    @State private var scannedTasks: [AccountTask] = []
    @State private var selected: Set<String> = []
    @State private var runner = TaskRunController()
    @State private var busyTaskID: String?
    @State private var isScanning = false
    @State private var isRunning = false
    @State private var toast: Toast?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.m) {
                    if let message = queue.error ?? jobs.error {
                        ErrorBanner(message: message, retry: retry)
                    }

                    if isInitialLoading {
                        LoadingSkeleton(rows: 3)
                    } else {
                        QueueStatusCard(queue: queue.value)
                        QueueItemsCard(items: queue.value?.items ?? [])
                        QueueActionsRow(
                            isScanning: isScanning,
                            isRunning: isRunning,
                            onScan: scanAll,
                            onRun: runQueue,
                            onPause: pauseQueue
                        )
                        ScanResultView(
                            tasks: scannedTasks,
                            selected: selected,
                            running: runner.states,
                            busyTaskID: busyTaskID,
                            onToggleTask: toggle(_:),
                            onToggleGroup: toggleGroup(_:select:),
                            onRunOne: runSingle(_:),
                            onAction: { task, action in perform(action, on: task) }
                        )
                        JobListView(jobs: jobs.value)
                    }
                }
                .padding(.horizontal, Metrics.m)
                .padding(.vertical, Metrics.m)
            }
            .navigationTitle("任务")
            .refreshable { await refreshAll() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新", systemImage: "arrow.clockwise", action: refresh)
                        .labelStyle(.iconOnly)
                        .disabled(isScanning || isRunning)
                }
            }
            .safeAreaInset(edge: .bottom) {
                selectionBar
            }
            .task { await poll() }
            .toast($toast)
        }
    }

    private var isInitialLoading: Bool {
        queue.value == nil && queue.error == nil
    }

    private var selectedTasks: [AccountTask] {
        scannedTasks.filter { selected.contains($0.id) }
    }

    // MARK: - 底部选择条

    @ViewBuilder
    private var selectionBar: some View {
        if !selected.isEmpty || runner.isRunning {
            HStack(spacing: Metrics.m) {
                if runner.isRunning {
                    ProgressView()
                        .controlSize(.small)
                    Text("执行中 \(runner.progressText)")
                        .font(.footnote.bold())
                        .contentTransition(.numericText())
                    if runner.failureCount > 0 {
                        Text("失败 \(runner.failureCount)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Button("停止") { runner.stop() }
                        .font(.footnote.bold())
                        .buttonStyle(.glass)
                } else {
                    Text("已选 \(selected.count) 项")
                        .font(.footnote.bold())
                        .contentTransition(.numericText())
                    Spacer()
                    Button("清空") { selected.removeAll() }
                        .font(.footnote)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    Button {
                        runSelected()
                    } label: {
                        Label("执行选中", systemImage: "play.fill")
                    }
                    .font(.footnote.bold())
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(.horizontal, Metrics.m)
            .padding(.vertical, Metrics.s)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, Metrics.m)
            .padding(.bottom, Metrics.s)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.snappy, value: selected.count)
        }
    }

    // MARK: - 加载

    private func refresh() {
        Task { await refreshAll() }
    }

    private func retry() {
        Task { await refreshAll() }
    }

    private func refreshAll() async {
        guard let client = session.client() else { return }
        await queue.load { try await client.taskQueue() }
        await jobs.load { try await client.taskJobs() }
    }

    /// 队列状态随调度推进变化，页面可见时每 10 秒拉一次；`.task` 在页面消失时自动取消。
    private func poll() async {
        await refreshAll()
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                return
            }
            await refreshAll()
        }
    }

    // MARK: - 勾选

    private func toggle(_ task: AccountTask) {
        if selected.contains(task.id) {
            selected.remove(task.id)
        } else {
            selected.insert(task.id)
        }
    }

    private func toggleGroup(_ tasks: [AccountTask], select: Bool) {
        if select {
            selected.formUnion(tasks.map(\.id))
        } else {
            selected.subtract(tasks.map(\.id))
        }
    }

    // MARK: - 扫描与执行

    private func scanAll() {
        Task {
            isScanning = true
            defer { isScanning = false }
            guard let client = session.client() else {
                toast = Toast(kind: .failure, text: "尚未配置服务器地址")
                return
            }
            do {
                let raw = try await client.scanAllTasks()
                let outcome = ActionOutcome(raw)
                guard outcome.ok else {
                    toast = Toast(kind: .failure, text: "扫描失败：\(outcome.message ?? "服务器拒绝")")
                    return
                }
                scannedTasks = AccountTaskParser.fromScan(raw)
                selected.removeAll()
                if scannedTasks.isEmpty {
                    toast = Toast(kind: .success, text: "扫描完成，暂无待办任务")
                } else {
                    let pending = raw.objectValue?["pending_count"]?.intValue ?? scannedTasks.count
                    toast = Toast(kind: .success, text: "扫描完成：\(pending) 项待办")
                }
                withAnimation(.snappy) { /* 列表入场 */ }
            } catch {
                guard !error.isCancellation else { return }
                toast = Toast(kind: .failure, text: "扫描失败：\(error.humanMessage)")
            }
        }
    }

    private func runQueue() {
        Task {
            isRunning = true
            defer { isRunning = false }
            await runBatch("tasks/run_queue", title: "执行队列", successText: "队列已启动")
        }
    }

    private func pauseQueue() {
        Task {
            await runBatch("tasks/pause", title: "暂停队列", successText: "暂停指令已发送")
        }
    }

    /// 执行勾选的任意任务（可跨账号）：账号间并发 2、账号内串行，与后端 per-account 锁一致。
    private func runSelected() {
        let tasks = selectedTasks
        guard !tasks.isEmpty else { return }
        Task {
            guard let client = session.client() else {
                toast = Toast(kind: .failure, text: "尚未配置服务器地址")
                return
            }
            guard !runner.isRunning else { return }
            await runner.run(tasks, client: client)
            // 只清掉真的跑完的；中途停止时没跑的保留勾选，方便继续
            selected.subtract(runner.finishedIDs)
            let ok = runner.successCount
            let failed = runner.failureCount
            toast = Toast(
                kind: failed == 0 ? .success : .failure,
                text: failed == 0 ? "已执行 \(ok) 项任务" : "完成 \(ok) 项，失败 \(failed) 项"
            )
            await refreshTasks(for: Set(tasks.map(\.uid)))
        }
    }

    // MARK: - 单项操作

    private func runSingle(_ task: AccountTask) {
        Task {
            busyTaskID = task.id
            defer { busyTaskID = nil }
            guard let client = session.client() else { return }
            do {
                let outcome = try await client.runTask(uid: task.uid, code: task.code)
                toast = Toast(
                    kind: outcome.isSuccess ? .success : .failure,
                    text: "\(task.title)：\(outcome.displayText)"
                )
                await refreshTasks(for: Set([task.uid]))
            } catch {
                guard !error.isCancellation else { return }
                toast = Toast(kind: .failure, text: "执行失败：\(error.humanMessage)")
            }
        }
    }

    private func perform(_ action: TaskAction, on task: AccountTask) {
        Task {
            busyTaskID = task.id
            defer { busyTaskID = nil }
            guard let client = session.client() else {
                toast = Toast(kind: .failure, text: "尚未配置服务器地址")
                return
            }
            do {
                let raw: JSONValue
                switch action {
                case .accept:
                    raw = try await client.acceptTasks(uid: task.uid, codes: [task.code])
                case .claim:
                    raw = try await client.claimTask(uid: task.uid, code: task.code)
                }
                let outcome = ActionOutcome(raw)
                var text = "\(task.title)\(action.rawValue)成功"
                if let credit = raw.objectValue?["credit"]?.intValue, credit > 0 {
                    text += "，+\(credit) 分"
                } else if raw.objectValue?["already_claimed"]?.boolValue == true {
                    text = "\(task.title)此前已领取"
                } else if let message = outcome.message {
                    text = message
                }
                toast = Toast(kind: outcome.ok ? .success : .failure, text: text)
                await refreshTasks(for: Set([task.uid]))
            } catch {
                guard !error.isCancellation else { return }
                toast = Toast(kind: .failure, text: "\(action.rawValue)失败：\(error.humanMessage)")
            }
        }
    }

    /// 批量刷新若干账号的任务状态并回填（避免整页重扫）。
    private func refreshTasks(for uids: Set<String>) async {
        guard let client = session.client(), !uids.isEmpty else { return }
        for uid in uids {
            guard let sample = scannedTasks.first(where: { $0.uid == uid }) else { continue }
            do {
                let raw = try await client.accountTasks(uid: uid)
                let fresh = AccountTaskParser.fromSingle(
                    raw,
                    uid: uid,
                    nickname: sample.nickname,
                    realm: sample.realm
                )
                let staleIDs = Set(scannedTasks.filter { $0.uid == uid }.map(\.id))
                scannedTasks.removeAll { staleIDs.contains($0.id) }
                scannedTasks.append(contentsOf: fresh)
            } catch {
                // 静默失败：状态刷新不影响操作结果
            }
        }
    }

    private func runBatch(_ action: String, title: String, successText: String) async {
        guard let client = session.client() else {
            toast = Toast(kind: .failure, text: "尚未配置服务器地址")
            return
        }
        do {
            let outcome = ActionOutcome(try await client.batch(action))
            guard outcome.ok else {
                toast = Toast(
                    kind: .failure,
                    text: "\(title)失败：\(outcome.message ?? "服务器拒绝了该操作")"
                )
                return
            }
            toast = Toast(kind: .success, text: outcome.message ?? successText)
            await refreshAll()
        } catch {
            guard !error.isCancellation else { return }
            toast = Toast(kind: .failure, text: "\(title)失败：\(error.humanMessage)")
        }
    }
}

