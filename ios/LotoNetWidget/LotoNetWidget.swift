import AppIntents
import SwiftUI
import WidgetKit

struct JackpotEntry: TimelineEntry {
    let date: Date
    let game: LotoGame
    let report: ReportResponse?
    let metrics: GameMetrics?
}

private enum JackpotDataLoader {
    static func placeholderEntry() -> JackpotEntry {
        let mockMetrics = GameMetrics(grossRon: 1000000, taxRon: 100000, netRon: 900000, netEur: 180000, stale: false)
        return JackpotEntry(date: Date(), game: .loto649, report: nil, metrics: mockMetrics)
    }

    static func loadEntry(for game: LotoGame) async -> JackpotEntry {
        let store = ReportStore()
        var report = store.loadCachedReport()

        do {
            let remote = try await store.fetchRemoteReport()
            if let freshReport = remote.report {
                report = freshReport
            }
        } catch {
            // Keep cache-only mode when network is unavailable.
        }

        return JackpotEntry(
            date: Date(),
            game: game,
            report: report,
            metrics: report?.metrics(for: game)
        )
    }

    static func nextRefreshDate(from report: ReportResponse?) -> Date {
        let minimumGap = Date().addingTimeInterval(60 * 60)
        let fallback = Date().addingTimeInterval(6 * 60 * 60)

        guard let nextExpected = report?.nextExpectedUpdateDate else {
            return fallback
        }

        let adjusted = nextExpected.addingTimeInterval(15 * 60)
        return adjusted > minimumGap ? adjusted : minimumGap
    }
}

@available(iOS 17.0, *)
struct JackpotIntentTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> JackpotEntry {
        JackpotDataLoader.placeholderEntry()
    }

    func snapshot(for configuration: GameSelectionIntent, in context: Context) async -> JackpotEntry {
        await JackpotDataLoader.loadEntry(for: configuration.game?.game ?? .loto649)
    }

    func timeline(for configuration: GameSelectionIntent, in context: Context) async -> Timeline<JackpotEntry> {
        let entry = await JackpotDataLoader.loadEntry(for: configuration.game?.game ?? .loto649)
        let refreshDate = JackpotDataLoader.nextRefreshDate(from: entry.report)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }
}

struct JackpotLegacyTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> JackpotEntry {
        JackpotDataLoader.placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (JackpotEntry) -> Void) {
        Task {
            let entry = await JackpotDataLoader.loadEntry(for: .loto649)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JackpotEntry>) -> Void) {
        Task {
            let entry = await JackpotDataLoader.loadEntry(for: .loto649)
            let refreshDate = JackpotDataLoader.nextRefreshDate(from: entry.report)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }
}

struct LotoNetWidgetEntryView: View {
    let entry: JackpotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.game.displayName)
                    .font(.headline)
                Spacer()
                if entry.metrics?.stale == true || entry.report?.stale == true {
                    Text("STALE")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
            }

            Text(DisplayFormatter.eur(entry.metrics?.netEur))
                .font(.title3.bold())
                .minimumScaleFactor(0.8)

            Text("Net EUR")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Text("Brut")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DisplayFormatter.ron(entry.metrics?.grossRon))
                    .font(.caption)
            }

            HStack {
                Text("Impozit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DisplayFormatter.ron(entry.metrics?.taxRon))
                    .font(.caption)
            }

            HStack {
                Text("Curs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DisplayFormatter.fx(entry.report?.eurRonRate))
                    .font(.caption)
            }
        }
        .padding(12)
    }
}

@available(iOSApplicationExtension 17.0, *)
struct LotoNetWidgetModern: Widget {
    let kind: String = WidgetConstants.kind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: GameSelectionIntent.self, provider: JackpotIntentTimelineProvider()) { entry in
            LotoNetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Report NET Loto")
        .description("Afiseaza reportul NET estimat pentru Loto 6/49 sau Joker.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LotoNetWidgetLegacy: Widget {
    let kind: String = WidgetConstants.kind + ".legacy"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JackpotLegacyTimelineProvider()) { entry in
            LotoNetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Report NET Loto")
        .description("Afiseaza reportul NET estimat pentru Loto 6/49.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOSApplicationExtension 17.0, *) {
            return []
        }
        return [.systemSmall, .systemMedium]
    }
}
