import SwiftUI

/// 账号详情：概览快照 + 积分 / 用量 / 成本 / 操作。
///
/// 刷新时重新调 `client.overview()`，按 uid 找回同一个账号。
struct AccountDetailView: View {
    @Environment(\.appTheme) private var theme

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var model = AccountDetailModel()
    @State private var isLeaving = false
    @State private var isShowingRelogin = false

    private let account: Account

    init(account: Account) {
        self.account = account
    }

    var body: some View {
        @Bindable var model = model
        let current = model.current(account)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.m) {
                if current.needsLogin {
                    actionBanner(current)
                        .staggeredAppear(index: 0)
                }

                DetailHeaderCard(account: current)
                    .staggeredAppear(index: current.needsLogin ? 1 : 0)

                if let message = model.error {
                    ErrorBanner(message: message) {
                        reload()
                    }
                }

                CreditsCard(account: current)
                    .staggeredAppear(index: 1)

                UsageCard(account: current)
                    .staggeredAppear(index: 2)

                ModelCostCard(account: current)
                    .staggeredAppear(index: 3)

                NavigationLink {
                    ModelTogglesView(account: current)
                } label: {
                    HStack(spacing: Metrics.s) {
                        Label("模型开关", systemImage: "switch.2")
                            .font(.callout)
                            .foregroundStyle(.primary)
                        Spacer()
                        if let off = current.modelOff, !off.isEmpty {
                            Text("已关闭 \(off.count) 个")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Text("全部开启")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(Metrics.m)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassCard(padding: 0, cornerRadius: Metrics.radiusM)
                .staggeredAppear(index: 4)

                ActionsCard(
                    account: current,
                    busy: model.busy,
                    onAction: perform,
                    onRemove: requestRemove
                )
                .staggeredAppear(index: 5)
            }
            .padding(.horizontal, Metrics.m)
            .padding(.top, Metrics.s)
            .padding(.bottom, Metrics.xl)
        }
        .scrollIndicators(.hidden)
        .background {
            LinearGradient(
                colors: [theme.soft.opacity(0.8), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .background(.background)
        .opacity(isLeaving ? 0 : 1)
        .scaleEffect(isLeaving ? 0.96 : 1)
        .allowsHitTesting(!isLeaving)
        .refreshable {
            await model.load(using: session.client(), syncBalance: true)
        }
        .navigationTitle(current.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: reload) {
                    if model.isLoading || model.isReloading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("刷新该账号")
            }
        }
        .sheet(isPresented: $isShowingRelogin) {
            ReloginView(account: current)
                .environment(session)
        }
        .toast($model.toast)
        .task {
            model.remember(account.uid)
            await model.load(using: session.client())
        }
    }

    /// 登录态失效时给一句人话 + 两个动作（重新登录 / 看日志）。
    private func actionBanner(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: Metrics.s) {
            HStack(spacing: Metrics.s) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(account.isDisabled ? "账号已禁用：登录态失效" : "登录态异常")
                    .font(.callout.bold())
                Spacer(minLength: 0)
            }

            Text(account.actionHint ?? "需要重新授权才能恢复调度。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Metrics.s) {
                Button {
                    isShowingRelogin = true
                } label: {
                    Label("重新登录", systemImage: "person.badge.key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                NavigationLink {
                    LogsView(keyword: account.nickname ?? account.uid)
                } label: {
                    Label("查看日志", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .padding(Metrics.m)
        .glassEffect(.regular.tint(.orange.opacity(0.12)), in: .rect(cornerRadius: Metrics.radiusM))
    }

    private func reload() {
        Task { await model.load(using: session.client(), syncBalance: true) }
    }

    private func perform(_ command: AccountCommand) {
        Task {
            await model.perform(command, on: model.current(account), using: session.client())
        }
    }

    private func requestRemove() {
        Task {
            let removed = await model.remove(account, using: session.client())
            guard removed else { return }
            withAnimation(Motion.emphasized) {
                isLeaving = true
            } completion: {
                dismiss()
            }
        }
    }
}
