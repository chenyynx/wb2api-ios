import SwiftUI

/// 账号列表的一行：和概览「账号池」完全同款——
/// NavigationLink + 12pt 内边距 + `glassInteractive`，点按走 zoom 转场。
/// 行操作放在长按菜单里（ScrollView 没有 swipeActions）。
struct AccountListRow: View {
    let account: Account
    var isBusy: Bool = false
    var namespace: Namespace.ID
    var onOpen: () -> Void
    var onRelogin: () -> Void = {}
    let onAction: (AccountCommand) -> Void

    var body: some View {
        NavigationLink(value: account) {
            AccountRowView(account: account, isBusy: isBusy)
                .padding(Metrics.m - Metrics.xs)
                .glassInteractive(cornerRadius: Metrics.radiusM)
        }
        .buttonStyle(.plain)
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.6)
                .scaleEffect(phase.isIdentity ? 1 : 0.97)
        }
        .contextMenu {
            Button {
                onAction(.checkin)
            } label: {
                Label("签到", systemImage: "checkmark.seal")
            }

            Button {
                onRelogin()
            } label: {
                Label("重新登录", systemImage: "person.badge.key")
            }

            Button {
                onAction(.revive)
            } label: {
                Label("复活", systemImage: "bolt.heart")
            }

            if !account.isDisabled {
                Button {
                    onAction(account.isPaused ? .resume : .pause)
                } label: {
                    Label(
                        account.isPaused ? "恢复" : "暂停",
                        systemImage: account.isPaused ? "play.fill" : "pause.fill"
                    )
                }
            }

            Divider()

            Button(role: .destructive) {
                onAction(.disable)
            } label: {
                Label("禁用", systemImage: "nosign")
            }
        }
    }
}
