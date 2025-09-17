import SwiftUI

struct PredictionDetailView: View {
    let loaded: LoadedPrediction

    private var prediction: NoHitterPrediction { loaded.prediction }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PredictionHeroView(prediction: prediction, history: loaded.history)
                pitcherSection
                matchupSection
                insightsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(prediction.pitcher.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: shareMessage) {
                Image(systemName: "square.and.arrow.up")
            }
        }
    }

    private var pitcherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pitcher Form")
                .font(.headline)
            if let stats = prediction.pitcher.recentPerformance {
                VStack(alignment: .leading, spacing: 8) {
                    Label("ERA \(stats.era.asDecimal) over \(stats.inningsPitched.asDecimal) IP", systemImage: "chart.line.flattrend.xyaxis")
                    Label("WHIP \(stats.whip.asDecimal)", systemImage: "drop")
                    Label("Strikeout Rate \(stats.strikeoutRate.asPercentage) • Walk Rate \(stats.walkRate.asPercentage)", systemImage: "flame")
                }
                .foregroundStyle(.primary)
            } else {
                Text("We couldn't obtain recent pitching data.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.thinMaterial))
    }

    private var matchupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Matchup Context")
                .font(.headline)
            if let game = prediction.pitcher.matchup {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Opponent: \(game.opponent.name)", systemImage: "person.3")
                    if let offense = game.opponentOffense {
                        Label("Opponent AVG \(offense.battingAverage.asDecimal) • OPS \(offense.onBasePlusSlugging.asDecimal)", systemImage: "chart.xyaxis.line")
                    }
                    Label("Ballpark: \(game.venue.name) — \(game.venue.city)", systemImage: "building.2")
                    if let elevation = game.venue.elevation {
                        Label("Elevation: \(Int(elevation)) ft", systemImage: "mountain.2")
                    }
                    if let weather = game.weather {
                        Label("Weather: \(Int(weather.temperature))°F, \(Int(weather.humidity))% humidity, wind \(Int(weather.windSpeed)) mph", systemImage: "cloud.sun")
                    }
                }
                .foregroundStyle(.primary)
            } else {
                Text("No matchup details yet — check back once MLB posts the probable starters.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.thinMaterial))
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
            ForEach(prediction.summary) { insight in
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(insight.detail)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.2))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension PredictionDetailView {
    private var shareMessage: String {
        let pitcher = prediction.pitcher
        let opponent = prediction.pitcher.matchup?.opponent.name ?? "TBD"
        let dateText = DateFormatting.short(date: prediction.date)
        let confidence = Int(prediction.confidenceScore.rounded())
        return "No-Hitter Predictor pick for \(dateText): \(pitcher.fullName) vs \(opponent). Confidence score \(confidence)."
    }
}

#Preview {
    let sample = LoadedPrediction(
        prediction: SampleData.prediction,
        lastUpdated: Date(),
        history: PredictionHistorySummary(highest: nil, lowest: nil, average: nil)
    )
    NavigationStack {
        PredictionDetailView(loaded: sample)
    }
}
