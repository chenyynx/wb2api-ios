import SwiftUI

/// 概览 Tab：健康度、指标、批量操作、账号预览。
///
/// 数据统一走 `client.overview()`（公网没有 `/status`）。
struct OverviewView: View {
    @Environment(\.appTheme) private var theme

    @Environment(SessionStore.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = OverviewModel()

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.m) {
                    OverviewHeaderView(
                        digest: model.digest,
                        lastUpdated: model.lastUpdated,
                        isRefreshing: model.isLoading
                    )
                    .staggeredAppear(index: 0)

                    if let message = model.error {
                        ErrorBanner(message: message) {
                            reload()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if let digest = model.digest, digest.total > 0 {
                        HealthCard(digest: digest)
                            .staggeredAppear(index: 1)

                        OverviewStatsGrid(digest: digest)
                            .staggeredAppear(index: 2)

                        ModelLocksCard(locks: model.overview?.modelLocks ?? [])
                            .staggeredAppear(index: 3)

                        UsageTrendCard(usage: model.usage)
                            .staggeredAppear(index: 4)

                        BatchActionsRow(running: model.runningBatch, onRun: runBatch)
                            .staggeredAppear(index: 5)
                    } else if model.isLoading {
                        LoadingSkeleton(rows: 5)
                    } else if model.overview != nil {
                        ContentUnavailableView {
                            Label("还没有账号", systemImage: "person.crop.circle.badge.plus")
                        } description: {
                            Text("在网页端登录 WorkBuddy 账号后，下拉刷新即可出现")
                        }
                        .frame(maxWidth: .infinity, minHeight: 320)
                    }
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
            .refreshable {
                await model.load(using: session.client(), syncBalance: true)
            }
            .navigationDestination(for: Account.self) { account in
                AccountDetailView(account: account)
            }
            .toolbar(.hidden, for: .navigationBar)
            .toast($model.toast)
            .onAppear {
                Task { await model.refreshIfStale(after: 5, using: session.client()) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await model.refreshIfStale(after: 5, using: session.client()) }
            }
        }
    }

    private func reload() {
        Task { await model.load(using: session.client(), syncBalance: true) }
    }

    private func runBatch(_ action: BatchAction) {
        Task { await model.run(action, using: session.client()) }
    }
}
