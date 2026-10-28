import SwiftUI

enum AppTab: Hashable {
    case overview, accounts, tasks, data, more
}

struct MainTabsView: View {
    @Environment(\.appTheme) private var theme

    @State private var selection: AppTab = .overview
    @State private var toast: Toast?

    var body: some View {
        TabView(selection: $selection) {
            Tab("概览", systemImage: "gauge.with.dots.needle.50percent", value: AppTab.overview) {
                OverviewView()
            }
            Tab("账号", systemImage: "person.2.fill", value: AppTab.accounts) {
                AccountsView()
            }
            Tab("任务", systemImage: "checklist", value: AppTab.tasks) {
                TasksView()
            }
            Tab("数据", systemImage: "chart.bar.xaxis", value: AppTab.data) {
                DataView()
            }
            Tab("更多", systemImage: "ellipsis", value: AppTab.more) {
                MoreView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(theme.primary)
        .toast($toast)
    }
}
