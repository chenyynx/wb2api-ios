import SwiftUI

@main
struct WB2APIApp: App {
    @State private var session = SessionStore()
    @AppStorage(AppTheme.storageKey) private var accentName = AccentChoice.violet.rawValue

    private var theme: AppTheme {
        AppTheme(accent: AccentChoice(rawValue: accentName) ?? .violet)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.appTheme, theme)
                .tint(theme.primary)
        }
    }
}
