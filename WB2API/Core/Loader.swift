import Foundation
import Observation

/// 通用加载器：统一 isLoading / error / value 三态，避免每个页面重写一遍。
@MainActor
@Observable
final class Loader<Value> {
    private(set) var value: Value?
    private(set) var error: String?
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?

    var isEmpty: Bool { value == nil && error == nil }

    /// 强制刷新允许并发，但只允许最新一轮写回——否则先发出的旧请求晚回来，
    /// 会把刚刷新的账号状态又盖回旧值（动作后刷新尤其明显）。
    private var generation = 0

    /// - Parameter force: 用户主动刷新时为 true——即使上一轮还没结束也再发一次，
    ///   避免「下拉没反应、数据停在旧值」。自动轮询保持 false，不并发堆请求。
    func load(force: Bool = false, _ operation: @escaping @MainActor () async throws -> Value) async {
        guard force || !isLoading else { return }
        generation += 1
        let token = generation
        isLoading = true
        defer { if token == generation { isLoading = false } }
        do {
            let result = try await operation()
            guard token == generation else { return }
            value = result
            error = nil
            lastUpdated = Date()
        } catch {
            guard token == generation else { return }
            // 下拉刷新 / 页面切换会取消进行中的请求，这不是真错误，别弹给用户
            guard !error.isCancellation else { return }
            // 已有数据时保留旧值，只更新错误提示（避免刷新失败把页面清空）
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearError() { error = nil }
}
