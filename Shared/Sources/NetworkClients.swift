import Foundation

public struct ProbablePitcherGame: Hashable {
    public let pitcherID: Int
    public let pitcherName: String
    public let throwingHand: ThrowingHand
    public let team: Team
    public let opponent: Team
    public let gameDate: Date
    public let venue: StadiumMetadata
}

public protocol MLBStatsProviding {
    func fetchProbablePitcherSchedule(for date: Date) async throws -> [ProbablePitcherGame]
    func fetchRecentStats(for pitcherID: Int, season: Int) async throws -> PitcherStats
    func fetchOffenseStats(for teamID: Int, season: Int) async throws -> TeamOffenseStats
    func fetchVenueDetails(for venueID: Int) async throws -> StadiumMetadata
}

public protocol WeatherProviding {
    func fetchWeather(for venue: StadiumMetadata, on date: Date) async throws -> WeatherSnapshot
}

public final class MLBStatsClient: MLBStatsProviding {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let seasonDetector: (Date) -> Int

    public init(session: URLSession = .shared,
                seasonDetector: @escaping (Date) -> Int = MLBStatsClient.defaultSeasonDetector) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.seasonDetector = seasonDetector
    }

    public func fetchProbablePitcherSchedule(for date: Date) async throws -> [ProbablePitcherGame] {
        let season = seasonDetector(date)
        let formattedDate = Self.scheduleFormatter.string(from: date)
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/schedule")!
        components.queryItems = [
            URLQueryItem(name: "sportId", value: "1"),
            URLQueryItem(name: "date", value: formattedDate),
            URLQueryItem(name: "hydrate", value: "team,probablePitcher,venue(location)"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "season", value: String(season))
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try decoder.decode(ScheduleResponse.self, from: data)
        let games = response.dates.flatMap { $0.games }

        return games.flatMap { game -> [ProbablePitcherGame] in
            let date = game.gameDate
            let venue = game.venue.makeMetadata()
            let homeSide = game.teams.home.makeProbable(gameDate: date, venue: venue, opponent: game.teams.away.team)
            let awaySide = game.teams.away.makeProbable(gameDate: date, venue: venue, opponent: game.teams.home.team)
            return [homeSide, awaySide].compactMap { $0 }
        }
    }

    public func fetchRecentStats(for pitcherID: Int, season: Int) async throws -> PitcherStats {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/people/\(pitcherID)/stats")!
        components.queryItems = [
            URLQueryItem(name: "stats", value: "gameLog"),
            URLQueryItem(name: "group", value: "pitching"),
            URLQueryItem(name: "season", value: String(season))
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try decoder.decode(PitcherLogResponse.self, from: data)
        guard let splits = response.stats.first?.splits.prefix(3), !splits.isEmpty else {
            throw MLBStatsClientError.noGameLogs
        }

        var innings = 0.0
        var earnedRuns = 0.0
        var hits = 0.0
        var walks = 0.0
        var strikeouts = 0.0
        var battersFaced = 0.0

        for split in splits {
            innings += split.stat.inningsPitchedDecimal
            earnedRuns += Double(split.stat.earnedRuns)
            hits += Double(split.stat.hits)
            walks += Double(split.stat.baseOnBalls)
            strikeouts += Double(split.stat.strikeOuts)
            battersFaced += Double(split.stat.battersFaced)
        }

        let era = innings > 0 ? (earnedRuns * 9.0) / innings : 99.0
        let whip = innings > 0 ? (walks + hits) / innings : 5.0
        let strikeoutRate = battersFaced > 0 ? strikeouts / battersFaced : 0
        let walkRate = battersFaced > 0 ? walks / battersFaced : 0
        let hitsPerNine = innings > 0 ? (hits * 9.0) / innings : 9.0

        return PitcherStats(
            era: era,
            whip: whip,
            strikeoutRate: strikeoutRate,
            walkRate: walkRate,
            hitsAllowedPerNine: hitsPerNine,
            inningsPitched: innings
        )
    }

    public func fetchOffenseStats(for teamID: Int, season: Int) async throws -> TeamOffenseStats {
        var components = URLComponents(string: "https://statsapi.mlb.com/api/v1/teams/\(teamID)/stats")!
        components.queryItems = [
            URLQueryItem(name: "stats", value: "season"),
            URLQueryItem(name: "group", value: "hitting"),
            URLQueryItem(name: "season", value: String(season))
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try decoder.decode(TeamStatsResponse.self, from: data)
        guard let stat = response.stats.first?.splits.first?.stat else {
            throw MLBStatsClientError.noTeamStats
        }

        let battingAverage = Double(stat.avg) ?? 0
        let strikeoutRate = stat.atBats > 0 ? Double(stat.strikeOuts) / Double(stat.atBats) : 0
        let ops = Double(stat.ops) ?? 0
        return TeamOffenseStats(battingAverage: battingAverage, strikeoutRate: strikeoutRate, onBasePlusSlugging: ops)
    }

    public func fetchVenueDetails(for venueID: Int) async throws -> StadiumMetadata {
        let url = URL(string: "https://statsapi.mlb.com/api/v1/venues/\(venueID)")!
        let (data, _) = try await session.data(from: url)
        let response = try decoder.decode(VenueResponse.self, from: data)
        guard let venue = response.venues.first else {
            throw MLBStatsClientError.noVenue
        }
        return venue.makeMetadata()
    }
}

public enum MLBStatsClientError: Error {
    case noGameLogs
    case noTeamStats
    case noVenue
}

public final class OpenMeteoWeatherClient: WeatherProviding {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    public func fetchWeather(for venue: StadiumMetadata, on date: Date) async throws -> WeatherSnapshot {
        guard let lat = venue.latitude, let lon = venue.longitude else {
            throw WeatherClientError.missingCoordinates
        }

        let day = OpenMeteoWeatherClient.dateFormatter.string(from: date)
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", lon)),
            URLQueryItem(name: "hourly", value: "temperature_2m,relativehumidity_2m,windspeed_10m,winddirection_10m"),
            URLQueryItem(name: "start_date", value: day),
            URLQueryItem(name: "end_date", value: day),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try decoder.decode(OpenMeteoResponse.self, from: data)
        guard let hourly = response.hourly else {
            throw WeatherClientError.noData
        }

        let count = min(hourly.temperature.count, hourly.humidity.count, hourly.windSpeed.count, hourly.windDirection.count)
        guard count > 0 else { throw WeatherClientError.noData }

        let temps = Array(hourly.temperature.prefix(count))
        let humidities = Array(hourly.humidity.prefix(count))
        let winds = Array(hourly.windSpeed.prefix(count))
        let directions = Array(hourly.windDirection.prefix(count))

        func average(_ values: [Double]) -> Double {
            guard !values.isEmpty else { return 0 }
            return values.reduce(0, +) / Double(values.count)
        }

        return WeatherSnapshot(
            temperature: average(temps),
            humidity: average(humidities),
            windSpeed: average(winds),
            windDirection: average(directions)
        )
    }
}

public enum WeatherClientError: Error {
    case missingCoordinates
    case noData
}

public extension MLBStatsClient {
    static let scheduleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func defaultSeasonDetector(_ date: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        if let openingDay = calendar.date(from: DateComponents(year: year, month: 4, day: 1)), date < openingDay {
            return year - 1
        }
        return year
    }
}

private struct ScheduleResponse: Decodable {
    let dates: [ScheduleDate]
}

private struct ScheduleDate: Decodable {
    let games: [ScheduleGame]
}

private struct ScheduleGame: Decodable {
    let gamePk: Int
    let gameDate: Date
    let venue: VenueSummary
    let teams: ScheduleTeams
}

private struct VenueSummary: Decodable {
    let id: Int
    let name: String
    let location: VenueLocation?
    let elevation: Double?

    struct VenueLocation: Decodable {
        let latitude: Double?
        let longitude: Double?
        let city: String?
        let state: String?
        let country: String?
    }

    func makeMetadata() -> StadiumMetadata {
        StadiumMetadata(
            id: id,
            name: name,
            city: location?.city ?? "",
            state: location?.state,
            country: location?.country ?? "USA",
            elevation: elevation,
            latitude: location?.latitude,
            longitude: location?.longitude,
            dimensions: nil
        )
    }
}

private struct ScheduleTeams: Decodable {
    let home: ScheduleTeam
    let away: ScheduleTeam
}

private struct ScheduleTeam: Decodable {
    let team: ScheduleTeamInfo
    let probablePitcher: SchedulePitcher?

    struct ScheduleTeamInfo: Decodable {
        let id: Int
        let name: String
        let teamName: String?
        let abbreviation: String?
        let venue: VenueIdWrapper?

        struct VenueIdWrapper: Decodable {
            let id: Int?
        }

        func makeTeam() -> Team {
            let abbr = abbreviation ?? String(name.prefix(3)).uppercased()
            return Team(id: id, name: name, abbreviation: abbr, venueIdentifier: venue?.id)
        }
    }

    struct SchedulePitcher: Decodable {
        let id: Int
        let fullName: String
        let pitchHand: PitchHand?

        struct PitchHand: Decodable {
            let code: String?
        }
    }

    func makeProbable(gameDate: Date, venue: StadiumMetadata, opponent: ScheduleTeamInfo) -> ProbablePitcherGame? {
        guard let pitcher = probablePitcher else { return nil }
        let team = team.makeTeam()
        let opponentTeam = opponent.makeTeam()
        return ProbablePitcherGame(
            pitcherID: pitcher.id,
            pitcherName: pitcher.fullName,
            throwingHand: ThrowingHand(rawValue: pitcher.pitchHand?.code),
            team: team,
            opponent: opponentTeam,
            gameDate: gameDate,
            venue: venue
        )
    }
}

private struct PitcherLogResponse: Decodable {
    let stats: [PitcherLog]

    struct PitcherLog: Decodable {
        let splits: [PitcherSplit]
    }
}

private struct PitcherSplit: Decodable {
    let stat: PitcherSplitStat
}

private struct PitcherSplitStat: Decodable {
    let earnedRuns: Int
    let hits: Int
    let baseOnBalls: Int
    let strikeOuts: Int
    let battersFaced: Int
    let inningsPitched: String

    var inningsPitchedDecimal: Double {
        if !inningsPitched.contains(".") {
            return Double(inningsPitched) ?? 0
        }
        let parts = inningsPitched.split(separator: ".")
        guard let wholePart = parts.first else { return 0 }
        let whole = Double(wholePart) ?? 0
        let remainderPart = parts.count > 1 ? parts[1] : Substring()
        let remainder = Double(remainderPart) ?? 0
        switch remainder {
        case 0: return whole
        case 1: return whole + (1.0 / 3.0)
        case 2: return whole + (2.0 / 3.0)
        default: return whole
        }
    }
}

private struct TeamStatsResponse: Decodable {
    let stats: [TeamStatEntry]

    struct TeamStatEntry: Decodable {
        let splits: [TeamStatSplit]
    }
}

private struct TeamStatSplit: Decodable {
    let stat: TeamHittingStat
}

private struct TeamHittingStat: Decodable {
    let avg: String
    let ops: String
    let atBats: Int
    let strikeOuts: Int
}

private struct VenueResponse: Decodable {
    let venues: [VenueDetail]
}

private struct VenueDetail: Decodable {
    let id: Int
    let name: String
    let location: VenueSummary.VenueLocation?
    let elevation: Double?
    let fieldInfo: FieldInfo?

    struct FieldInfo: Decodable {
        let leftLine: Int?
        let leftCenter: Int?
        let center: Int?
        let rightCenter: Int?
        let rightLine: Int?
    }

    func makeMetadata() -> StadiumMetadata {
        StadiumMetadata(
            id: id,
            name: name,
            city: location?.city ?? "",
            state: location?.state,
            country: location?.country ?? "USA",
            elevation: elevation,
            latitude: location?.latitude,
            longitude: location?.longitude,
            dimensions: FieldDimensions(
                leftLine: fieldInfo?.leftLine,
                leftCenter: fieldInfo?.leftCenter,
                center: fieldInfo?.center,
                rightCenter: fieldInfo?.rightCenter,
                rightLine: fieldInfo?.rightLine
            )
        )
    }
}

private struct OpenMeteoResponse: Decodable {
    let hourly: Hourly?

    struct Hourly: Decodable {
        let time: [String]
        let temperature: [Double]
        let humidity: [Double]
        let windSpeed: [Double]
        let windDirection: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case humidity = "relativehumidity_2m"
            case windSpeed = "windspeed_10m"
            case windDirection = "winddirection_10m"
        }
    }
}

private extension OpenMeteoWeatherClient {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
