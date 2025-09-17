import SwiftUI

@main
struct NoHitterPredictorApp: App {
    private let environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}

private struct RootView: View {
    let environment: AppEnvironment

    var body: some View {
        TabView {
            DashboardView(environment: environment)
                .tabItem {
                    Label("Today", systemImage: "sparkles")
                }
            HistoryView(environment: environment)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
