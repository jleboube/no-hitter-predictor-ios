import SwiftUI

struct HistoryView: View {
    let environment: AppEnvironment
    @State private var rows: [HistoryRow] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading history…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if rows.isEmpty {
                    historyUnavailable
                } else {
                        List(rows) { row in
                            HistoryRowView(row: row)
                                .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                }
            }
            .navigationTitle("History")
        }
        .task {
            await loadHistory()
        }
        .onAppear {
            Task { await loadHistory() }
        }
    }

    @ViewBuilder
    private var historyUnavailable: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                "No saved predictions yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Come back after the next daily pick runs.")
            )
        } else {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No saved predictions yet")
                    .font(.headline)
                Text("Come back after the next daily pick runs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @MainActor
    private func loadHistory() async {
        isLoading = true
        let entries = environment.historyEntries()
        let mapped = entries.map { entry in
            HistoryRow(entry: entry, prediction: environment.prediction(for: entry))
        }
        rows = mapped
        isLoading = false
    }
}

private struct HistoryRow: Identifiable {
    let entry: PredictionHistoryEntry
    let prediction: NoHitterPrediction?

    var id: Date { entry.date }
}

private struct HistoryRowView: View {
    let row: HistoryRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(DateFormatting.short(date: row.entry.date))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("Confidence \(Int(row.entry.score))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(row.entry.pitcherName)
                .font(.headline)
            if let prediction = row.prediction {
                Text(detail(for: prediction))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func detail(for prediction: NoHitterPrediction) -> String {
        let team = prediction.pitcher.team.abbreviation
        let opponent = prediction.pitcher.matchup?.opponent.abbreviation ?? "TBD"
        return "\(team) vs \(opponent)"
    }
}

#Preview {
    HistoryView(environment: AppEnvironment.live())
}
