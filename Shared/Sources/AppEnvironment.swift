import Foundation

public struct AppEnvironment {
    public var statsClient: MLBStatsProviding
    public var weatherClient: WeatherProviding
    public var stadiums: StadiumDataProviding
    public var predictionEngine: PredictionEngine
    public var cache: PredictionCache

    public init(statsClient: MLBStatsProviding,
                weatherClient: WeatherProviding,
                stadiums: StadiumDataProviding,
                predictionEngine: PredictionEngine,
                cache: PredictionCache) {
        self.statsClient = statsClient
        self.weatherClient = weatherClient
        self.stadiums = stadiums
        self.predictionEngine = predictionEngine
        self.cache = cache
    }
}

public enum PredictionServiceError: Error {
    case noProbablePitchers
    case scoringFailure
}

public final class PredictionCache {
    private let userDefaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let calendar = Calendar(identifier: .gregorian)
    private let cachePrefix = "prediction-cache-"
    private let historyKey = "prediction-history-cache"

    public init(userDefaults: UserDefaults = .standard) {
        if let suite = UserDefaults(suiteName: PredictionCache.suiteName) {
            self.userDefaults = suite
        } else {
            self.userDefaults = userDefaults
        }
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func cachedPrediction(for date: Date) -> NoHitterPrediction? {
        guard let data = userDefaults.data(forKey: key(for: date)) else { return nil }
        return try? decoder.decode(NoHitterPrediction.self, from: data)
    }

    public func store(_ prediction: NoHitterPrediction, for date: Date) {
        guard let data = try? encoder.encode(prediction) else { return }
        userDefaults.set(data, forKey: key(for: date))
        storeHistoryEntry(for: prediction)
    }

    private func key(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(cachePrefix)\(year)-\(month)-\(day)"
    }

    private func storeHistoryEntry(for prediction: NoHitterPrediction) {
        let entry = PredictionHistoryEntry(
            date: prediction.date,
            score: prediction.confidenceScore,
            pitcherName: prediction.pitcher.fullName,
            pitcherID: prediction.pitcher.id
        )
        var history = historyEntries()
        history.removeAll { calendar.isDate($0.date, inSameDayAs: entry.date) }
        history.append(entry)
        if let data = try? encoder.encode(history.sorted { $0.date < $1.date }) {
            userDefaults.set(data, forKey: historyKey)
        }
    }

    public func historyEntries() -> [PredictionHistoryEntry] {
        guard let data = userDefaults.data(forKey: historyKey),
              let entries = try? decoder.decode([PredictionHistoryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    public func historySummary() -> PredictionHistorySummary {
        let entries = historyEntries()
        let highest = entries.max(by: { $0.score < $1.score })
        let lowest = entries.min(by: { $0.score < $1.score })
        let average = entries.isEmpty ? nil : (entries.map { $0.score }.reduce(0, +) / Double(entries.count))
        return PredictionHistorySummary(highest: highest, lowest: lowest, average: average)
    }

    public static let suiteName = "group.com.joeleboube.nohitter"
}

public extension AppEnvironment {
    static func live() -> AppEnvironment {
        let cache = PredictionCache()
        let stadiumProvider = StadiumDataProvider(bundle: .main)
        return AppEnvironment(
            statsClient: MLBStatsClient(),
            weatherClient: OpenMeteoWeatherClient(),
            stadiums: stadiumProvider,
            predictionEngine: PredictionEngine(),
            cache: cache
        )
    }

    func fetchPrediction(for date: Date = Date(), forceRefresh: Bool = false, includeWeather: Bool = true) async throws -> NoHitterPrediction {
        if !forceRefresh, let cached = cache.cachedPrediction(for: date) {
            return cached
        }

        do {
            let probable = try await statsClient.fetchProbablePitcherSchedule(for: date)
            guard !probable.isEmpty else {
                throw PredictionServiceError.noProbablePitchers
            }

            let season = determineSeason(for: date)
            var assembled: [Pitcher] = []

            for game in probable {
                async let statsResult = try? statsClient.fetchRecentStats(for: game.pitcherID, season: season)
                async let offenseResult = try? statsClient.fetchOffenseStats(for: game.opponent.id, season: season)

                var venueMetadata = stadiums.stadium(by: game.venue.id) ?? game.venue
                if venueMetadata.dimensions == nil || venueMetadata.latitude == nil {
                    if let detailed = try? await statsClient.fetchVenueDetails(for: game.venue.id) {
                        venueMetadata = detailed
                        stadiums.upsert(detailed)
                    }
                }

                let weather = includeWeather ? (try? await weatherClient.fetchWeather(for: venueMetadata, on: game.gameDate)) : nil
                guard let stats = await statsResult else { continue }
                let offense = await offenseResult

                let context = GameContext(
                    date: game.gameDate,
                    opponent: game.opponent,
                    venue: venueMetadata,
                    opponentOffense: offense,
                    weather: weather
                )

                let pitcher = Pitcher(
                    id: game.pitcherID,
                    fullName: game.pitcherName,
                    team: game.team,
                    throwingHand: game.throwingHand,
                    recentPerformance: stats,
                    matchup: context
                )
                assembled.append(pitcher)
            }

            guard let prediction = predictionEngine.scorePitchers(assembled, for: date) else {
                throw PredictionServiceError.scoringFailure
            }

            cache.store(prediction, for: date)
            return prediction
        } catch {
            NSLog("Prediction fetch error: %@", String(describing: error))

            if let cached = cache.cachedPrediction(for: date) {
                return cached
            }

            let fallback = SampleData.prediction
            cache.store(fallback, for: date)
            return fallback
        }
    }

    private func determineSeason(for date: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        if let openingDay = calendar.date(from: DateComponents(year: year, month: 4, day: 1)), date < openingDay {
            return year - 1
        }
        return year
    }

    func cachedPrediction(for date: Date = Date()) -> NoHitterPrediction? {
        cache.cachedPrediction(for: date)
    }

    func historySummary() -> PredictionHistorySummary {
        cache.historySummary()
    }

    func historyEntries() -> [PredictionHistoryEntry] {
        cache.historyEntries()
            .sorted { $0.date > $1.date }
    }

    func prediction(for entry: PredictionHistoryEntry) -> NoHitterPrediction? {
        cache.cachedPrediction(for: entry.date)
    }
}

public struct PredictionHistoryEntry: Codable, Equatable {
    public let date: Date
    public let score: Double
    public let pitcherName: String
    public let pitcherID: Int
}

public struct PredictionHistorySummary: Equatable {
    public let highest: PredictionHistoryEntry?
    public let lowest: PredictionHistoryEntry?
    public let average: Double?
}
