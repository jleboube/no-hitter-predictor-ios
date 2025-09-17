import SwiftUI

struct SettingsView: View {
    private static let sharedDefaults = UserDefaults(suiteName: PredictionCache.suiteName) ?? .standard

    @AppStorage("nohitter.widgetRefreshInterval", store: sharedDefaults) private var widgetRefreshInterval: Double = 6
    @AppStorage("nohitter.includeWeather", store: sharedDefaults) private var includeWeather: Bool = true

    var body: some View {
        NavigationView {
            Form {
                Section("Prediction Preferences") {
                    Toggle("Incorporate weather outlook", isOn: $includeWeather)
                    Stepper(value: $widgetRefreshInterval, in: 3...12, step: 1) {
                        Text("Widget refresh every \(Int(widgetRefreshInterval)) hours")
                    }
                    Text("Predictions publish once daily and syndicate automatically to the widget.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Data Sources") {
                    Link(destination: URL(string: "https://statsapi.mlb.com")!) {
                        Label("MLB Stats API", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://open-meteo.com")!) {
                        Label("Open-Meteo", systemImage: "link")
                    }
                }

                Section("Disclaimers") {
                    Text("Predictions are for entertainment and informational purposes only. No guarantees, no wagering.")
                    Text("All statistics are sourced from publicly available MLB data and refreshed daily without manual intervention.")
                }

                Section("Feedback") {
                    Link(destination: URL(string: "mailto:feedback@nohitterapp.com")!) {
                        Label("Share feedback", systemImage: "mail")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
