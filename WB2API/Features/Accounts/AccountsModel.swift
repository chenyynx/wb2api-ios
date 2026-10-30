import Foundation
import Observation

/// 账号列表的数据、筛选与单号操作。
@MainActor
@Observable
final class AccountsModel {
    private let loader = Loader<OverviewResponse>()

    var query = ""
    var filter: AccountFilter = .all
    var toast: Toast?
    private(set) var busyUIDs: Set<String> = []
    /// 覆盖「同步上游余额 + 重拉 overview」整段；按钮转圈用它，别只看 loader.isLoading
    private(set) var isReloading = false

    var accounts: [Account] { loader.value?.accounts ?? [] }
    var isLoading: Bool { loader.isLoading }
    var error: String? { loader.error }
    var lastUpdated: Date? { loader.lastUpdated }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 搜索 + 筛选后的结果，顺序沿用面板返回顺序。
    var filtered: [Account] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return accounts.filter { account in
            guard filter.matches(account) else { return false }
            guard !keyword.isEmpty else { return true }
            return account.displayName.localizedCaseInsensitiveContains(keyword)
                || account.uid.localizedCaseInsensitiveContains(keyword)
        }
    }

    var emptyTitle: String {
        filter == .all ? "还没有账号" : "没有符合条件的账号"
    }

    var emptyIcon: String { "person.2.slash" }

    var emptyMessage: String {
        filter == .all
            ? "在网页端登录 WorkBuddy 账号后，下拉刷新即可出现"
            : "换个筛选条件，或把筛选切回「全部」"
    }

    func count(for option: AccountFilter) -> Int {
        accounts.filter(option.matches).count
    }

    // MARK: 读取

    func refreshIfStale(after interval: TimeInterval = 3, using client: APIClient?) async {
        if loader.isLoading { return }
        if let last = loader.lastUpdated, Date().timeIntervalSince(last) < interval { return }
        await load(using: client)
    }

    /// - Parameter syncBalance: 用户主动刷新时为 true——先让后端查一轮上游余额，
    ///   否则面板缓存的积分不会变。节流期内跳过上游同步但仍然重拉 overview。
    /// - Parameter force: 动作完成后必须传入 true——否则遇到进行中的轮询会被跳过，
    ///   列表看起来「操作了但状态没变」。
    func load(using client: APIClient?, syncBalance: Bool = false, force: Bool = false) async {
        guard let client else {
            toast = Toast(kind: .failure, text: "尚未配置服务器地址")
            return
        }
        if syncBalance {
            isReloading = true
            await BalanceSync.refreshAll(client: client)
        }
        defer { if syncBalance { isReloading = false } }
        // 主动刷新 / 动作后重读都强制重发，不被进行中的轮询挡掉
        await loader.load(force: syncBalance || force) { try await client.overview() }
        guard syncBalance else { return }
        if let error = loader.error {
            toast = Toast(kind: .failure, text: error)
        } else {
            toast = Toast(kind: .info, text: "已刷新账号状态")
        }
    }

    // MARK: 单号操作

    func perform(_ command: AccountCommand, on account: Account, using client: APIClient?) async {
        guard let client else {
            toast = Toast(kind: .failure, text: "尚未配置服务器地址")
            return
        }
        guard !busyUIDs.contains(account.uid) else { return }

        busyUIDs.insert(account.uid)
        defer { _ = busyUIDs.remove(account.uid) }

        do {
            let outcome = ActionOutcome(try await client.accountAction(account.uid, action: command.rawValue))
            guard outcome.ok else {
                toast = Toast(
                    kind: .failure,
                    text: "\(command.title)失败：\(outcome.message ?? "服务器拒绝了该操作")"
                )
                return
            }
            toast = Toast(
                kind: .success,
                text: outcome.message ?? "\(account.displayName) · \(command.title)已提交"
            )
            // 强制重读：复活 / 恢复后必须立刻反映到列表状态
            await load(using: client, force: true)
        } catch {
            toast = Toast(kind: .failure, text: "\(command.title)失败：\(error.humanMessage)")
        }
    }
}
