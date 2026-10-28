import Foundation

extension TaskQueue {
    var isRunning: Bool { running ?? false }

    var totalCount: Int { total ?? items?.count ?? 0 }

    private var statuses: [String] {
        (items ?? []).compactMap { $0.objectValue?["status"]?.stringValue }
    }

    var doneCount: Int { statuses.filter { $0 == "done" }.count }
    var skippedCount: Int { statuses.filter { $0 == "skipped" }.count }
    var failedCount: Int { statuses.filter { $0 == "error" || $0 == "failed" }.count }
    var runningItemCount: Int { statuses.filter { $0 == "running" }.count }

    private var pendingItemCount: Int {
        statuses.filter { status in
            status != "done" && status != "skipped" && status != "error"
                && status != "failed" && status != "running"
        }.count
    }

    /// 已处理 = 完成 + 跳过 + 失败。
    var processedCount: Int { doneCount + skippedCount + failedCount }

    /// 真正还没跑完的项；total 大于明细条数时，把未列出的部分按待处理算。
    var remainingCount: Int {
        guard !statuses.isEmpty else { return totalCount }
        let listed = runningItemCount + pendingItemCount
        return max(listed, totalCount - processedCount)
    }

    var isFinished: Bool {
        totalCount > 0 && !isRunning && !statuses.isEmpty && remainingCount == 0
    }

    /// 卡片标题旁的状态：运行中 / 已完成 / 有失败 / 空闲。
    var stateText: String {
        if isRunning { return "运行中" }
        if isFinished { return failedCount > 0 ? "有失败" : "已完成" }
        return "空闲"
    }
}
