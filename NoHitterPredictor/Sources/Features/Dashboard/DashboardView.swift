import SwiftUI
import WidgetKit

struct DashboardView: View {
    @StateObject private var viewModel: PredictionViewModel
    @State private var selectedPrediction: LoadedPrediction?

    init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: PredictionViewModel(environment: environment))
    }

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Today's Pick")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if let loaded = viewModel.currentLoaded {
                            ShareLink(item: shareMessage(for: loaded)) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Share prediction")

                            if viewModel.canRetry {
                                Button(action: { Task { await viewModel.retry() } }) {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .accessibilityLabel("Retry fetching live data")
                            }
                        }
                    }
                }
        }
        .sheet(item: $selectedPrediction) { loaded in
            NavigationStack {
                PredictionDetailView(loaded: loaded)
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            await viewModel.loadInitial()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Crunching the numbers…")
                .padding()
        case .failed(let message):
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    "Unable to fetch today's pick",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                .padding()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Unable to fetch today's pick")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        case .loaded(let model):
            ScrollView {
                VStack(spacing: 24) {
                    PredictionHeroView(prediction: model.prediction, history: model.history)
                        .onTapGesture {
                            selectedPrediction = model
                        }

                    if model.isSampleData {
                        SampleDataNotice(retryAction: {
                            Task { await viewModel.retry() }
                        }, canRetry: viewModel.canRetry)
                    }

                    metricsSection(for: model.prediction)
                    insightsSection(for: model.prediction)
                    dataSourceSection(lastUpdated: model.lastUpdated, prediction: model.prediction)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await viewModel.retry()
            }
        }
    }

    private func metricsSection(for prediction: NoHitterPrediction) -> some View {
        let stats = prediction.pitcher.recentPerformance
        let matchup = prediction.pitcher.matchup
        return VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                if let stats {
                    StatChipView(title: "ERA", value: stats.era.asDecimal, subtitle: "Last 3 starts", icon: "chart.line.uptrend.xyaxis")
                    StatChipView(title: "WHIP", value: stats.whip.asDecimal, subtitle: "Last 3 starts", icon: "drop")
                    StatChipView(title: "Strikeout Rate", value: stats.strikeoutRate.asPercentage, subtitle: "Per batter faced", icon: "flame")
                    StatChipView(title: "Walk Rate", value: stats.walkRate.asPercentage, subtitle: "Per batter faced", icon: "figure.walk")
                }
                if let opponent = matchup?.opponentOffense {
                    StatChipView(title: "Opponent AVG", value: opponent.battingAverage.asDecimal, subtitle: "Season to date", icon: "baseball" )
                    StatChipView(title: "Opponent OPS", value: opponent.onBasePlusSlugging.asDecimal, subtitle: "Season to date", icon: "speedometer")
                }
            }
        }
    }

    private func insightsSection(for prediction: NoHitterPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why This Works")
                .font(.headline)
            ForEach(prediction.summary) { insight in
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(insight.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.secondary.opacity(0.15))
                )
            }
        }
    }

    private func dataSourceSection(lastUpdated: Date, prediction: NoHitterPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Sources")
                .font(.headline)
            Label("MLB Stats API — Probable pitchers, venue data, recent logs", systemImage: "chart.bar.doc.horizontal")
            Label("Open-Meteo — Game-day weather outlook", systemImage: "cloud.sun")
            Label("Opponent trends from team-wide batting splits", systemImage: "person.3.sequence")
            Label("Updated \(DateFormatting.short(date: lastUpdated))", systemImage: "clock.arrow.2.circlepath")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Entertainment only. Predictions are not guarantees; enjoy responsibly.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func shareMessage(for loaded: LoadedPrediction) -> String {
        let prediction = loaded.prediction
        let pitcher = prediction.pitcher
        let opponent = prediction.pitcher.matchup?.opponent.name ?? "TBD"
        let dateText = DateFormatting.short(date: prediction.date)
        let confidence = Int(prediction.confidenceScore.rounded())
        return "No-Hitter Predictor pick for \(dateText): \(pitcher.fullName) vs \(opponent). Confidence score \(confidence)."
    }
}

struct LoadedPrediction {
    let prediction: NoHitterPrediction
    let lastUpdated: Date
    let history: PredictionHistorySummary

    var isSampleData: Bool { prediction.isSampleData }
}

extension LoadedPrediction: Identifiable {
    var id: Int { prediction.id }
}

@MainActor
final class PredictionViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(LoadedPrediction)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let environment: AppEnvironment
    private let defaults = UserDefaults(suiteName: PredictionCache.suiteName) ?? .standard

    private var includeWeather: Bool {
        defaults.object(forKey: "nohitter.includeWeather") as? Bool ?? true
    }

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func loadInitial() async {
        guard case .idle = state else { return }
        if let cached = environment.cachedPrediction() {
            let summary = environment.historySummary()
            let loaded = LoadedPrediction(prediction: cached, lastUpdated: Date(), history: summary)
            state = .loaded(loaded)
        } else {
            await loadPrediction(force: false)
        }
    }

    var currentLoaded: LoadedPrediction? {
        if case let .loaded(loaded) = state { return loaded }
        return nil
    }

    var canRetry: Bool {
        switch state {
        case .failed:
            return true
        case .loaded(let loaded):
            return loaded.isSampleData
        default:
            return false
        }
    }

    func retry() async {
        guard canRetry else { return }
        await loadPrediction(force: true)
    }

    private func loadPrediction(force: Bool) async {
        await MainActor.run {
            state = .loading
        }

        do {
            let prediction = try await environment.fetchPrediction(for: Date(), forceRefresh: force, includeWeather: includeWeather)
            let summary = environment.historySummary()
            let loaded = LoadedPrediction(prediction: prediction, lastUpdated: Date(), history: summary)
            await MainActor.run {
                withAnimation(.spring) {
                    state = .loaded(loaded)
                }
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            await MainActor.run {
                withAnimation {
                    state = .failed(error.userFacingMessage)
                }
            }
        }
    }
}

private extension Error {
    var userFacingMessage: String {
        if let predictionError = self as? PredictionServiceError {
            switch predictionError {
            case .noProbablePitchers:
                return "MLB hasn't posted today’s probable pitchers yet. Check back soon."
            case .scoringFailure:
                return "We couldn't score today’s matchups. Try refreshing in a moment."
            }
        }
        return "Something unexpected happened. Please try again later."
    }
}

struct PredictionHeroView: View {
    let prediction: NoHitterPrediction
    let history: PredictionHistorySummary

    var body: some View {
        let palette = TeamBranding.palette(for: prediction.pitcher.team)
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    PitcherHeadshotView(pitcher: prediction.pitcher)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(prediction.pitcher.fullName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(prediction.pitcher.team.name) • \(handedness(prediction.pitcher))")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                        if let game = prediction.pitcher.matchup {
                            Text("vs \(game.opponent.name) • \(DateFormatting.short(date: game.date))")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    Spacer()
                    ConfidenceBadgeView(score: prediction.confidenceScore)
                }

                ConfidenceContextSection(prediction: prediction, history: history)

                if let matchup = prediction.pitcher.matchup, let weather = matchup.weather {
                    HStack(alignment: .center, spacing: 16) {
                        Label("Temp \(Int(weather.temperature))°", systemImage: "thermometer")
                        Label("Humidity \(Int(weather.humidity))%", systemImage: "drop.fill")
                        Label("Wind \(Int(weather.windSpeed)) mph", systemImage: "wind")
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                }
            }

            if prediction.isSampleData {
                SampleHeroBadge()
                    .padding(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.primary, palette.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: palette.primary.opacity(0.3), radius: 10, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }

    private func handedness(_ pitcher: Pitcher) -> String {
        switch pitcher.throwingHand {
        case .left:
            return "LHP"
        case .right:
            return "RHP"
        case .switchHand:
            return "Switch"
        case .unknown:
            return "Pitcher"
        }
    }

}

private struct ConfidenceContextSection: View {
    let prediction: NoHitterPrediction
    let history: PredictionHistorySummary

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Confidence score reflects the strength of recent form, matchup, venue, and weather inputs.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
            if let highlight = primarySummaryText {
                Text(highlight)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
            }
            if let supporting = secondarySummaryText {
                Text(supporting)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var primarySummaryText: String? {
        guard let highest = history.highest else { return nil }
        if isSameDay(highest) {
            return "Highest confidence we’ve logged this season."
        }
        return "Season high: \(Int(highest.score)) — \(highest.pitcherName) on \(DateFormatting.short(date: highest.date))."
    }

    private var secondarySummaryText: String? {
        if let lowest = history.lowest, !isSameDay(lowest) {
            return "Season low: \(Int(lowest.score)) — \(lowest.pitcherName) on \(DateFormatting.short(date: lowest.date))."
        }
        if let average = history.average {
            return String(format: "Average confidence this season: %.0f", average)
        }
        return nil
    }

    private func isSameDay(_ entry: PredictionHistoryEntry) -> Bool {
        calendar.isDate(entry.date, inSameDayAs: prediction.date) && entry.pitcherID == prediction.pitcher.id
    }
}

private struct SampleHeroBadge: View {
    var body: some View {
        Label("Sample Data", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2), in: Capsule())
            .foregroundStyle(.white)
    }
}

private struct SampleDataNotice: View {
    let retryAction: () -> Void
    let canRetry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Showing sample data while we reconnect to MLB.", systemImage: "wifi.exclamationmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.yellow)
            Text("Pull to refresh or tap retry once your connection stabilizes.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if canRetry {
                Button(action: retryAction) {
                    Label("Retry now", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemYellow).opacity(0.15))
        )
    }
}

private struct PitcherHeadshotView: View {
    var pitcher: Pitcher

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .frame(width: 86, height: 86)
            AsyncImage(url: pitcher.headshotURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 86, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                case .failure:
                    TeamBadgeView(team: pitcher.team)
                        .frame(width: 72, height: 72)
                case .empty:
                    ProgressView()
                        .frame(width: 72, height: 72)
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

private struct ConfidenceBadgeView: View {
    var score: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Confidence")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text(String(format: "%.0f", score))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.2))
        )
    }
}

#Preview {
    DashboardView(environment: AppEnvironment.live())
}
