import Foundation

enum LotoGame: String, Codable, CaseIterable, Identifiable {
    case loto649
    case joker

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .loto649:
            return "Loto 6/49"
        case .joker:
            return "Joker"
        }
    }
}

struct ReportResponse: Codable {
    let generatedAtUtc: String?
    let sourceTimestamps: SourceTimestamps
    let eurRonRate: Double?
    let fxRateDate: String?
    let games: GameCollection
    let nextExpectedUpdateAt: String?
    let updateReason: String
    let stale: Bool
    let errors: [String]

    func metrics(for game: LotoGame) -> GameMetrics {
        games.metrics(for: game)
    }

    var generatedAtDate: Date? {
        guard let generatedAtUtc else { return nil }
        return ISO8601DateFormatter.shared.date(from: generatedAtUtc)
    }

    var nextExpectedUpdateDate: Date? {
        guard let nextExpectedUpdateAt else { return nil }
        return ISO8601DateFormatter.shared.date(from: nextExpectedUpdateAt)
    }
}

struct SourceTimestamps: Codable {
    let lotoFetchedAtUtc: String?
    let fxFetchedAtUtc: String?
    let fxRateDate: String?
}

struct GameCollection: Codable {
    let loto649: GameMetrics
    let joker: GameMetrics

    func metrics(for game: LotoGame) -> GameMetrics {
        switch game {
        case .loto649:
            return loto649
        case .joker:
            return joker
        }
    }
}

struct GameMetrics: Codable {
    let grossRon: Double?
    let taxRon: Double?
    let netRon: Double?
    let netEur: Double?
    let stale: Bool
}

enum ReportDecode {
    static func decode(_ data: Data) throws -> ReportResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ReportResponse.self, from: data)
    }
}

extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
