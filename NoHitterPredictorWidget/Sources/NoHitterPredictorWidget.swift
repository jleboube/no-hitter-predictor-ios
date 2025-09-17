import WidgetKit
import SwiftUI
import UIKit

struct NoHitterPredictorProvider: TimelineProvider {
    func placeholder(in context: Context) -> PredictionEntry {
        PredictionEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (PredictionEntry) -> Void) {
        completion(PredictionEntry.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PredictionEntry>) -> Void) {
        Task {
            let environment = AppEnvironment.live()
            let now = Date()
            let sharedDefaults = UserDefaults(suiteName: PredictionCache.suiteName) ?? .standard
            let refreshInterval = max(sharedDefaults.double(forKey: "nohitter.widgetRefreshInterval"), 3)
            let nextRefresh = Calendar.current.date(byAdding: .hour, value: Int(refreshInterval), to: now) ?? now.addingTimeInterval(21_600)
            let includeWeather = sharedDefaults.object(forKey: "nohitter.includeWeather") as? Bool ?? true

            if let cached = environment.cachedPrediction(for: now) {
                let imageData = await headshotData(for: cached.pitcher)
                let entry = PredictionEntry(date: now, prediction: cached, imageData: imageData, isPlaceholder: false)
                completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
                return
            }

            do {
                let prediction = try await environment.fetchPrediction(for: now, forceRefresh: false, includeWeather: includeWeather)
                let imageData = await headshotData(for: prediction.pitcher)
                let entry = PredictionEntry(date: now, prediction: prediction, imageData: imageData, isPlaceholder: false)
                completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
            } catch {
                let fallback = PredictionEntry(date: now, prediction: nil, imageData: nil, isPlaceholder: false)
                completion(Timeline(entries: [fallback], policy: .after(nextRefresh)))
            }
        }
    }

    private func headshotData(for pitcher: Pitcher) async -> Data? {
        guard let url = pitcher.headshotURL else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }
}

struct NoHitterPredictorWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PredictionEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallPredictionView(entry: entry)
        case .systemMedium:
            MediumPredictionView(entry: entry)
        case .systemLarge:
            LargePredictionView(entry: entry)
        default:
            MediumPredictionView(entry: entry)
        }
    }
}

struct NoHitterPredictorWidget: Widget {
    let kind: String = "NoHitterPredictorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoHitterPredictorProvider()) { entry in
            NoHitterPredictorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("No-Hitter Predictor")
        .description("See today's most likely no-hitter candidate at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct SmallPredictionView: View {
    var entry: PredictionEntry

    var body: some View {
        if let prediction = entry.prediction {
            let palette = TeamBranding.palette(for: prediction.pitcher.team)
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [palette.primary, palette.secondary], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 8) {
                    WidgetPitcherImageView(pitcher: prediction.pitcher, image: entry.headshotImage)
                        .frame(width: 64, height: 64)
                    Text(prediction.pitcher.fullName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text("Confidence \(Int(prediction.confidenceScore))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding()
                if prediction.isSampleData {
                    SampleWidgetBadge()
                        .padding(6)
                }
            }
        } else {
            placeholder("Awaiting today's probable pitchers")
        }
    }
}

private struct MediumPredictionView: View {
    var entry: PredictionEntry

    var body: some View {
        if let prediction = entry.prediction, let stats = prediction.pitcher.recentPerformance {
            let palette = TeamBranding.palette(for: prediction.pitcher.team)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 16) {
                    WidgetPitcherImageView(pitcher: prediction.pitcher, image: entry.headshotImage)
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(prediction.pitcher.fullName)
                            .font(.headline)
                        if let matchup = prediction.pitcher.matchup {
                            Text("vs \(matchup.opponent.abbreviation)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("Confidence \(Int(prediction.confidenceScore))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            statColumn(title: "ERA", value: stats.era.asDecimal)
                            statColumn(title: "WHIP", value: stats.whip.asDecimal)
                            statColumn(title: "K%", value: stats.strikeoutRate.asPercentage)
                        }
                    }
                    Spacer()
                }
                .padding()
                if prediction.isSampleData {
                    SampleWidgetBadge()
                        .padding(6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(colors: [palette.primary.opacity(0.15), palette.secondary.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        } else {
            placeholder("Pulling data…")
        }
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

private struct LargePredictionView: View {
    var entry: PredictionEntry

    var body: some View {
        if let prediction = entry.prediction {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 16) {
                    WidgetPitcherImageView(pitcher: prediction.pitcher, image: entry.headshotImage)
                        .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(prediction.pitcher.fullName)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                        if let matchup = prediction.pitcher.matchup {
                            Text("vs \(matchup.opponent.name)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(DateFormatting.short(date: prediction.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Confidence \(Int(prediction.confidenceScore))")
                            .font(.caption.weight(.semibold))
                        if let stats = prediction.pitcher.recentPerformance {
                            HStack(spacing: 12) {
                                statBlock(title: "ERA", value: stats.era.asDecimal)
                                statBlock(title: "WHIP", value: stats.whip.asDecimal)
                                statBlock(title: "K%", value: stats.strikeoutRate.asPercentage)
                            }
                        }
                        if let offense = prediction.pitcher.matchup?.opponentOffense {
                            Text(String(format: "Opp AVG %.3f", offense.battingAverage))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                if prediction.isSampleData {
                    SampleWidgetBadge()
                        .padding(6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("WidgetBackground"))
        } else {
            placeholder("Check back once MLB posts lineups.")
        }
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
        }
    }
}

private func placeholder(_ message: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: "sparkles")
            .font(.title)
        Text("No-Hitter Predictor")
            .font(.headline)
        Text(message)
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color("WidgetBackground"))
}

private extension Optional where Wrapped == Double {
    var asDecimal: String {
        guard let value = self else { return "-.--" }
        return String(format: "%.2f", value)
    }
}

private struct WidgetTeamBadgeView: View {
    var team: Team

    var body: some View {
        let palette = TeamBranding.palette(for: team)
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [palette.primary, palette.secondary], center: .center, startRadius: 4, endRadius: 40)
                )
            Text(team.abbreviation)
                .font(.caption.bold())
                .foregroundStyle(.white)
        }
    }
}

private struct SampleWidgetBadge: View {
    var body: some View {
        Text("Sample")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.2), in: Capsule())
            .foregroundColor(.white)
    }
}

private struct WidgetPitcherImageView: View {
    var pitcher: Pitcher
    var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
            WidgetTeamBadgeView(team: pitcher.team)
                .frame(width: 48, height: 48)
        }
    }
}

#if DEBUG
@available(iOSApplicationExtension 16.0, *)
struct NoHitterPredictorWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NoHitterPredictorWidgetEntryView(entry: PredictionEntry(date: .now, prediction: SampleData.prediction, imageData: nil, isPlaceholder: false))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            NoHitterPredictorWidgetEntryView(entry: PredictionEntry.placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
#endif
