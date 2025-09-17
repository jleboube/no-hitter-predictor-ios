import Foundation

public struct PredictionEngine {
    public init() {}

    public func scorePitchers(_ pitchers: [Pitcher], for date: Date) -> NoHitterPrediction? {
        guard let top = pitchers.max(by: { scoringScore(for: $0) < scoringScore(for: $1) }) else {
            return nil
        }

        let score = scoringScore(for: top)
        let insights = makeInsights(for: top, score: score)
        return NoHitterPrediction(date: date, pitcher: top, confidenceScore: score, summary: insights)
    }

    private func scoringScore(for pitcher: Pitcher) -> Double {
        guard let stats = pitcher.recentPerformance else { return 0 }

        var total = 0.0
        total += max(0, 90 - stats.era * 12)
        total += max(0, 80 - stats.whip * 40)
        total += stats.strikeoutRate * 120
        total -= stats.walkRate * 60
        total -= stats.hitsAllowedPerNine * 5
        total += min(stats.inningsPitched * 2.5, 35)

        if let weather = pitcher.matchup?.weather {
            total += weatherAdjustments(weather)
        }

        if let venue = pitcher.matchup?.venue {
            total += venueAdjustment(venue)
        }

        if let offense = pitcher.matchup?.opponentOffense {
            total += offenseAdjustment(offense)
        }

        return max(0, total)
    }

    private func weatherAdjustments(_ weather: WeatherSnapshot) -> Double {
        let optimalTemp = 68.0
        let tempVariance = abs(weather.temperature - optimalTemp)
        let tempScore = max(0, 20 - tempVariance * 1.2)

        let humidityScore = max(0, 15 - abs(weather.humidity - 55) * 0.5)
        let windScore = max(0, 12 - weather.windSpeed * 1.5)
        return tempScore + humidityScore + windScore
    }

    private func venueAdjustment(_ venue: StadiumMetadata) -> Double {
        var adjustment = 0.0
        if let elevation = venue.elevation {
            let avgElevation = 500.0
            adjustment += max(-10, min(10, (avgElevation - elevation) / 100))
        }
        if let center = venue.dimensions?.center {
            adjustment += Double(center - 400) / 10.0
        }
        return adjustment
    }

    private func offenseAdjustment(_ offense: TeamOffenseStats) -> Double {
        var value = 0.0
        value -= offense.battingAverage * 200
        value -= offense.onBasePlusSlugging * 50
        value += (0.30 - offense.strikeoutRate) * 120
        return value
    }

    private func makeInsights(for pitcher: Pitcher, score: Double) -> [PredictionInsight] {
        var insights: [PredictionInsight] = []
        if let stats = pitcher.recentPerformance {
            let eraText = String(format: "ERA %.2f", stats.era)
            let whipText = String(format: "WHIP %.2f", stats.whip)
            insights.append(PredictionInsight(title: "Last 3 Starts", detail: "\(eraText) | \(whipText)", weight: 0.3))
            insights.append(PredictionInsight(title: "Dominance", detail: "K% \(Int(stats.strikeoutRate * 100)) vs BB% \(Int(stats.walkRate * 100))", weight: 0.2))
        }
        if let offense = pitcher.matchup?.opponentOffense {
            let avg = String(format: "AVG %.3f", offense.battingAverage)
            insights.append(PredictionInsight(title: "Opponent Bats", detail: "\(avg) | K% \(Int(offense.strikeoutRate * 100))", weight: 0.15))
        }
        if let matchup = pitcher.matchup {
            let elevation = matchup.venue.elevation.map { "Elev. \(Int($0)) ft" } ?? ""
            let venueSummary = [matchup.venue.name, elevation].filter { !$0.isEmpty }.joined(separator: " • ")
            insights.append(PredictionInsight(title: "Venue", detail: venueSummary, weight: 0.15))
            insights.append(PredictionInsight(title: "Opponent", detail: matchup.opponent.name, weight: 0.1))
        }
        insights.append(PredictionInsight(title: "Confidence", detail: String(format: "Score %.1f", score), weight: 0.1))
        return insights
    }
}
