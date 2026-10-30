import Foundation
import Observation

/// 账号详情的数据与单号操作。
///
/// 刷新时重新拉 `overview()`，再按 uid 找到同一个账号。
@MainActor
@Observable
final class AccountDetailModel {
    private let loader = Loader<OverviewResponse>()

    var toast: Toast?
    private(set) var busy: AccountCommand?
    private(set) var isReloading = false

    var isLoading: Bool { loader.isLoading }
    var error: String? { loader.error }
    var lastUpdated: Date? { loader.lastUpdated }

    /// 用最新快照里的同 uid 账号；找不到时退回列表传入的快照。
    func current(_ fallback: Account) -> Account {
        loader.value?.accounts.first { $0.uid == fallback.uid } ?? fallback
    }

    /// - Parameter syncBalance: 用户主动刷新时为 true——先查这个号的上游余额再读快照。
    /// - Parameter force: 动作完成后传 true，避免被进行中的轮询跳过。
    func load(using client: APIClient?, syncBalance: Bool = false, force: Bool = false) async {
        guard let client else {
            toast = Toast(kind: .failure, text: "尚未配置服务器地址")
            return
        }
        if syncBalance, let uid = lastUID {
            isReloading = true
            await BalanceSync.refreshAccount(uid, client: client)
        }
        defer { if syncBalance { isReloading = false } }
        await loader.load(force: syncBalance || force) { try await client.overview() }
        guard syncBalance else { return }
        if let error = loader.error {
            toast = Toast(kind: .failure, text: error)
        } else {
            toast = Toast(kind: .info, text: "已刷新")
        }
    }

    /// 记住当前查看的账号，供余额同步用。
    private(set) var lastUID: String?
    func remember(_ uid: String) { lastUID = uid }

    func perform(_ command: AccountCommand, on account: Account, using client: APIClient?) async {
        guard let client else {
            toast = Toast(kind: .failure, text: "尚未配置服务器地址")
            return
        }
        guard busy == nil else { return }

        busy = command
        defer { busy = nil }

        do {
            let outcome = ActionOutcome(try await client.accountAction(account.uid, action: command.rawValue))
            guard outcome.ok else {
                toast = Toast(
                    kind: .failure,
                    text: "\(command.title)失败：\(outcome.message ?? "服务器拒绝了该操作")"
                )
                return
            }
            toast = Toast(kind: .success, text: outcome.message ?? "\(command.title)已完成")
            // 复活 / 恢复后状态要立刻变，不能让旧快照留在页面上
            await load(using: client, force: true)
        } catch {
            toast = Toast(kind: .failure, text: "\(command.title)失败：\(error.humanMessage)")
        }
    }

    /// 移除账号。返回 true 表示服务端已确认，调用方负责关闭页面。
    func remove(_ account: Account, using client: APIClient?) async -> Bool {
        guard let client else {
            toast = Toast(kind: .failure, text: "尚未配置服务器地址")
            return false
        }
        guard busy == nil else { return false }

        busy = .remove
        defer { busy = nil }

        do {
            let outcome = ActionOutcome(
                try await client.accountAction(account.uid, action: AccountCommand.remove.rawValue)
            )
            guard outcome.ok else {
                toast = Toast(kind: .failure, text: "移除失败：\(outcome.message ?? "服务器拒绝了该操作")")
                return false
            }
            toast = Toast(kind: .success, text: outcome.message ?? "已移除 \(account.displayName)")
            return true
        } catch {
            toast = Toast(kind: .failure, text: "移除失败：\(error.humanMessage)")
            return false
        }
    }
}
