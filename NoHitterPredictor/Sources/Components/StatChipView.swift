import SwiftUI

struct StatChipView: View {
    var title: String
    var value: String
    var subtitle: String? = nil
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

struct TeamBadgeView: View {
    var team: Team

    var body: some View {
        let palette = TeamBranding.palette(for: team)
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [palette.primary, palette.secondary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(team.abbreviation)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
        }
        .frame(width: 56, height: 56)
        .shadow(color: palette.primary.opacity(0.25), radius: 6, x: 0, y: 4)
        .accessibilityHidden(true)
    }
}

#if DEBUG
struct StatChipView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StatChipView(title: "ERA", value: "2.15", subtitle: "Last 3 starts", icon: "chart.line.uptrend.xyaxis")
                .padding()
                .previewDisplayName("Stat Chip")

            TeamBadgeView(team: Team(id: 121, name: "New York Mets", abbreviation: "NYM"))
                .padding()
                .previewDisplayName("Team Badge")
        }
        .previewLayout(.sizeThatFits)
        .background(Color(.systemBackground))
    }
}
#endif
