import Foundation

public struct Pitcher: Identifiable, Hashable, Codable {
    public let id: Int
    public let fullName: String
    public let team: Team
    public let throwingHand: ThrowingHand
    public var recentPerformance: PitcherStats?
    public var matchup: GameContext?

    public init(id: Int,
                fullName: String,
                team: Team,
                throwingHand: ThrowingHand,
                recentPerformance: PitcherStats? = nil,
                matchup: GameContext? = nil) {
        self.id = id
        self.fullName = fullName
        self.team = team
        self.throwingHand = throwingHand
        self.recentPerformance = recentPerformance
        self.matchup = matchup
    }
}

public struct Team: Hashable, Codable {
    public let id: Int
    public let name: String
    public let abbreviation: String
    public let venueIdentifier: Int?

    public init(id: Int, name: String, abbreviation: String, venueIdentifier: Int? = nil) {
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.venueIdentifier = venueIdentifier
    }
}

public enum ThrowingHand: String, Codable, Hashable {
    case left = "L"
    case right = "R"
    case switchHand = "S"
    case unknown = "?"

    public init(rawValue: String?) {
        switch rawValue?.uppercased() {
        case "L": self = .left
        case "R": self = .right
        case "S": self = .switchHand
        default: self = .unknown
        }
    }
}

public struct PitcherStats: Hashable, Codable {
    public let era: Double
    public let whip: Double
    public let strikeoutRate: Double
    public let walkRate: Double
    public let hitsAllowedPerNine: Double
    public let inningsPitched: Double

    public init(era: Double,
                whip: Double,
                strikeoutRate: Double,
                walkRate: Double,
                hitsAllowedPerNine: Double,
                inningsPitched: Double) {
        self.era = era
        self.whip = whip
        self.strikeoutRate = strikeoutRate
        self.walkRate = walkRate
        self.hitsAllowedPerNine = hitsAllowedPerNine
        self.inningsPitched = inningsPitched
    }
}

public struct TeamOffenseStats: Hashable, Codable {
    public let battingAverage: Double
    public let strikeoutRate: Double
    public let onBasePlusSlugging: Double

    public init(battingAverage: Double,
                strikeoutRate: Double,
                onBasePlusSlugging: Double) {
        self.battingAverage = battingAverage
        self.strikeoutRate = strikeoutRate
        self.onBasePlusSlugging = onBasePlusSlugging
    }
}

public struct GameContext: Hashable, Codable {
    public let date: Date
    public let opponent: Team
    public let venue: StadiumMetadata
    public let opponentOffense: TeamOffenseStats?
    public let weather: WeatherSnapshot?

    public init(date: Date,
                opponent: Team,
                venue: StadiumMetadata,
                opponentOffense: TeamOffenseStats?,
                weather: WeatherSnapshot? = nil) {
        self.date = date
        self.opponent = opponent
        self.venue = venue
        self.opponentOffense = opponentOffense
        self.weather = weather
    }

    public func updatingWeather(_ value: WeatherSnapshot) -> GameContext {
        GameContext(date: date, opponent: opponent, venue: venue, opponentOffense: opponentOffense, weather: value)
    }
}

public struct StadiumMetadata: Hashable, Codable {
    public let id: Int
    public let name: String
    public let city: String
    public let state: String?
    public let country: String
    public let elevation: Double?
    public let latitude: Double?
    public let longitude: Double?
    public let dimensions: FieldDimensions?

    public init(id: Int,
                name: String,
                city: String,
                state: String?,
                country: String,
                elevation: Double?,
                latitude: Double?,
                longitude: Double?,
                dimensions: FieldDimensions?) {
        self.id = id
        self.name = name
        self.city = city
        self.state = state
        self.country = country
        self.elevation = elevation
        self.latitude = latitude
        self.longitude = longitude
        self.dimensions = dimensions
    }
}

public struct FieldDimensions: Hashable, Codable {
    public let leftLine: Int?
    public let leftCenter: Int?
    public let center: Int?
    public let rightCenter: Int?
    public let rightLine: Int?

    public init(leftLine: Int?, leftCenter: Int?, center: Int?, rightCenter: Int?, rightLine: Int?) {
        self.leftLine = leftLine
        self.leftCenter = leftCenter
        self.center = center
        self.rightCenter = rightCenter
        self.rightLine = rightLine
    }
}

public struct WeatherSnapshot: Hashable, Codable {
    public let temperature: Double
    public let humidity: Double
    public let windSpeed: Double
    public let windDirection: Double

    public init(temperature: Double,
                humidity: Double,
                windSpeed: Double,
                windDirection: Double) {
        self.temperature = temperature
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
    }
}

public struct NoHitterPrediction: Hashable, Codable {
    public let date: Date
    public let pitcher: Pitcher
    public let confidenceScore: Double
    public let summary: [PredictionInsight]
    public let isSampleData: Bool

    public init(date: Date, pitcher: Pitcher, confidenceScore: Double, summary: [PredictionInsight], isSampleData: Bool = false) {
        self.date = date
        self.pitcher = pitcher
        self.confidenceScore = confidenceScore
        self.summary = summary
        self.isSampleData = isSampleData
    }
}

extension NoHitterPrediction: Identifiable {
    public var id: Int { pitcher.id }
}

public struct PredictionInsight: Hashable, Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let weight: Double

    public init(id: UUID = UUID(), title: String, detail: String, weight: Double) {
        self.id = id
        self.title = title
        self.detail = detail
        self.weight = weight
    }
}
