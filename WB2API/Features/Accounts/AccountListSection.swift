import SwiftUI

/// 账号列表主体：骨架 / 空态 / 卡片集合。
///
/// 原来用 `List` —— List 会把 `glassEffect` 压平，同一张玻璃卡在概览（ScrollView）
/// 里是通透的，在账号页却发灰。这里改成和概览一致：ScrollView + LazyVStack。
/// 行操作（签到/复活/暂停/禁用）保留在长按菜单里。
struct AccountListSection: View {
    @Environment(\.appTheme) private var theme

    let model: AccountsModel
    let zoomNamespace: Namespace.ID
    var onReload: () -> Void
    var onOpen: (Account) -> Void
    var onRelogin: (Account) -> Void
    var onCommand: (AccountCommand, Account) -> Void
    var onResetFilter: () -> Void = {}

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.s) {
                if let message = model.error {
                    ErrorBanner(message: message, retry: onReload)
                }

                if model.isLoading && model.accounts.isEmpty {
                    LoadingSkeleton(rows: 6)
                } else if model.filtered.isEmpty {
                    AccountsEmptyState(
                        isSearching: model.isSearching,
                        query: model.query,
                        title: model.emptyTitle,
                        systemImage: model.emptyIcon,
                        message: model.emptyMessage,
                        isFiltered: model.filter != .all
                    ) {
                        onResetFilter()
                    }
                } else {
                    updateStamp

                    ForEach(model.filtered) { account in
                        AccountListRow(
                            account: account,
                            isBusy: model.busyUIDs.contains(account.uid),
                            namespace: zoomNamespace,
                            onOpen: { onOpen(account) },
                            onRelogin: { onRelogin(account) }
                        ) { command in
                            onCommand(command, account)
                        }
                    }
                }
            }
            .padding(.horizontal, Metrics.m)
            .padding(.bottom, Metrics.xl)
        }
        .scrollIndicators(.hidden)
        // 与概览同款暖紫渐变：玻璃需要背后的颜色才通透。
        .background {
            LinearGradient(
                colors: [theme.soft.opacity(0.9), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .background(.background)
        .navigationTitle("账号")
    }

    private var updateStamp: some View {
        HStack(spacing: Metrics.xs) {
            Image(systemName: "clock.arrow.circlepath")
            Text("更新于 \(updateText)")
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.top, Metrics.xs)
    }

    private var updateText: String {
        guard let date = model.lastUpdated else { return "—" }
        return date.formatted(date: .omitted, time: .standard)
    }
}
