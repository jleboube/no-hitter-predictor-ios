import Foundation
import SwiftUI

public enum DateFormatting {
    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public static func short(date: Date) -> String {
        displayFormatter.string(from: date)
    }
}

public extension Bundle {
    static var sharedAppBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(identifier: "com.joeleboube.NoHitterPredictor") ?? .main
        #endif
    }
}

public extension Double {
    var asPercentage: String {
        String(format: "%.0f%%", self * 100)
    }

    var asDecimal: String {
        String(format: "%.2f", self)
    }
}

public struct TeamPalette {
    public let primary: Color
    public let secondary: Color
}

public enum TeamBranding {
    public static func palette(for team: Team) -> TeamPalette {
        if let colors = palettes[team.abbreviation] {
            return colors
        }
        return TeamPalette(primary: Color(hex: "0F172A"), secondary: Color(hex: "1E293B"))
    }

    private static let palettes: [String: TeamPalette] = [
        "ARI": .init(primary: Color(hex: "A71930"), secondary: Color(hex: "E3D4AD")),
        "ATL": .init(primary: Color(hex: "CE1141"), secondary: Color(hex: "13274F")),
        "BAL": .init(primary: Color(hex: "DF4601"), secondary: Color(hex: "000000")),
        "BOS": .init(primary: Color(hex: "BD3039"), secondary: Color(hex: "0D2B56")),
        "CHC": .init(primary: Color(hex: "0E3386"), secondary: Color(hex: "CC3433")),
        "CWS": .init(primary: Color(hex: "27251F"), secondary: Color(hex: "C4CED4")),
        "CIN": .init(primary: Color(hex: "C6011F"), secondary: Color(hex: "000000")),
        "CLE": .init(primary: Color(hex: "00385D"), secondary: Color(hex: "E50022")),
        "COL": .init(primary: Color(hex: "333366"), secondary: Color(hex: "C4CED4")),
        "DET": .init(primary: Color(hex: "0C2340"), secondary: Color(hex: "FA4616")),
        "HOU": .init(primary: Color(hex: "002D62"), secondary: Color(hex: "EB6E1F")),
        "KC": .init(primary: Color(hex: "004687"), secondary: Color(hex: "C09A5B")),
        "LAA": .init(primary: Color(hex: "BA0021"), secondary: Color(hex: "003263")),
        "LAD": .init(primary: Color(hex: "005A9C"), secondary: Color(hex: "EF3E42")),
        "MIA": .init(primary: Color(hex: "00A3E0"), secondary: Color(hex: "000000")),
        "MIL": .init(primary: Color(hex: "0A2351"), secondary: Color(hex: "B6922E")),
        "MIN": .init(primary: Color(hex: "002B5C"), secondary: Color(hex: "D31145")),
        "NYM": .init(primary: Color(hex: "002D72"), secondary: Color(hex: "FF5910")),
        "NYY": .init(primary: Color(hex: "003087"), secondary: Color(hex: "C4CED4")),
        "OAK": .init(primary: Color(hex: "003831"), secondary: Color(hex: "EFB21E")),
        "PHI": .init(primary: Color(hex: "E81828"), secondary: Color(hex: "002D72")),
        "PIT": .init(primary: Color(hex: "FDB827"), secondary: Color(hex: "000000")),
        "SD": .init(primary: Color(hex: "2F241D"), secondary: Color(hex: "FFC425")),
        "SEA": .init(primary: Color(hex: "005C5C"), secondary: Color(hex: "0C2C56")),
        "SF": .init(primary: Color(hex: "FD5A1E"), secondary: Color(hex: "27251F")),
        "STL": .init(primary: Color(hex: "C41E3A"), secondary: Color(hex: "0A2252")),
        "TB": .init(primary: Color(hex: "092C5C"), secondary: Color(hex: "8FBCE6")),
        "TEX": .init(primary: Color(hex: "003278"), secondary: Color(hex: "C0111F")),
        "TOR": .init(primary: Color(hex: "134A8E"), secondary: Color(hex: "1D2D5C")),
        "WSH": .init(primary: Color(hex: "AB0003"), secondary: Color(hex: "14225A"))
    ]
}

private extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch value.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 15, 23, 42)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

public extension Pitcher {
    var headshotURL: URL? {
        URL(string: "https://img.mlbstatic.com/mlb-photos/image/upload/w_300,q_auto:best/v1/people/\(id)/headshot/67/current")
    }
}

public enum SampleData {
    public static let prediction: NoHitterPrediction = {
        let team = Team(id: 121, name: "New York Mets", abbreviation: "NYM")
        let opponent = Team(id: 147, name: "New York Yankees", abbreviation: "NYY")
        let venue = StadiumMetadata(
            id: 3289,
            name: "Citi Field",
            city: "New York",
            state: "NY",
            country: "USA",
            elevation: 3,
            latitude: 40.7571,
            longitude: -73.8458,
            dimensions: FieldDimensions(leftLine: 335, leftCenter: 370, center: 408, rightCenter: 375, rightLine: 330)
        )
        let offense = TeamOffenseStats(battingAverage: 0.245, strikeoutRate: 0.24, onBasePlusSlugging: 0.712)
        let weather = WeatherSnapshot(temperature: 68, humidity: 48, windSpeed: 8, windDirection: 180)
        let matchup = GameContext(date: Date(), opponent: opponent, venue: venue, opponentOffense: offense, weather: weather)
        let stats = PitcherStats(era: 1.98, whip: 0.92, strikeoutRate: 0.32, walkRate: 0.06, hitsAllowedPerNine: 5.1, inningsPitched: 21.2)
        let pitcher = Pitcher(id: 592789, fullName: "Jacob deGrom", team: team, throwingHand: .right, recentPerformance: stats, matchup: matchup)
        let insights = [
            PredictionInsight(title: "Last 3 starts", detail: "ERA 1.98 | WHIP 0.92", weight: 0.3),
            PredictionInsight(title: "Strikeouts", detail: "K% 32 vs BB% 6", weight: 0.2),
            PredictionInsight(title: "Opponent", detail: "Yankees offense trending down", weight: 0.2)
        ]
        return NoHitterPrediction(date: Date(), pitcher: pitcher, confidenceScore: 87.4, summary: insights, isSampleData: true)
    }()
}
