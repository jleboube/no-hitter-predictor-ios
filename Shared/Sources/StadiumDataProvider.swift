import Foundation

public protocol StadiumDataProviding {
    func stadium(by id: Int) -> StadiumMetadata?
    func allStadiums() -> [StadiumMetadata]
    func upsert(_ stadium: StadiumMetadata)
}

public final class StadiumDataProvider: StadiumDataProviding {
    private var stadiums: [Int: StadiumMetadata]

    public init(bundle: Bundle = .main) {
        let decoder = JSONDecoder()
        if let url = StadiumDataProvider.locateResource(in: bundle),
           let data = try? Data(contentsOf: url),
           let decoded = try? decoder.decode([StadiumMetadata].self, from: data) {
            stadiums = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        } else {
            stadiums = [:]
        }
    }

    private static func locateResource(in bundle: Bundle) -> URL? {
        if let url = bundle.url(forResource: "stadiums", withExtension: "json") {
            return url
        }
        let bundleCandidates = [Bundle.main, Bundle(for: BundleMarker.self)] + Bundle.allBundles
        for candidate in bundleCandidates {
            if let url = candidate.url(forResource: "stadiums", withExtension: "json") {
                return url
            }
        }
        return nil
    }

    public func stadium(by id: Int) -> StadiumMetadata? {
        stadiums[id]
    }

    public func allStadiums() -> [StadiumMetadata] {
        Array(stadiums.values)
    }

    public func upsert(_ stadium: StadiumMetadata) {
        stadiums[stadium.id] = stadium
    }
}

private final class BundleMarker {}
