import AppIntents
import SwiftUI
import WidgetKit

struct JackpotEntry: TimelineEntry {
    let date: Date
    let game: LotoGame
    let report: ReportResponse?
    let metrics: GameMetrics?
}

@available(iOS 17.0, *)
struct JackpotTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> JackpotEntry {
        let mockMetrics = GameMetrics(grossRon: 1000000, taxRon: 100000, netRon: 900000, netEur: 180000, stale: false)
        return JackpotEntry(date: Date(), game: .loto649, report: nil, metrics: mockMetrics)
    }

    func snapshot(for configuration: GameSelectionIntent, in context: Context) async -> JackpotEntry {
        await loadEntry(for: configuration.game.game)
    }

    func timeline(for configuration: GameSelectionIntent, in context: Context) async -> Timeline<JackpotEntry> {
        let entry = await loadEntry(for: configuration.game.game)
        let refreshDate = nextRefreshDate(from: entry.report)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func loadEntry(for game: LotoGame) async -> JackpotEntry {
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

    private func nextRefreshDate(from report: ReportResponse?) -> Date {
        let minimumGap = Date().addingTimeInterval(60 * 60)
        let fallback = Date().addingTimeInterval(6 * 60 * 60)

        guard let nextExpected = report?.nextExpectedUpdateDate else {
            return fallback
        }

        let adjusted = nextExpected.addingTimeInterval(15 * 60)
        return adjusted > minimumGap ? adjusted : minimumGap
    }
}

@available(iOSApplicationExtension 17.0, *)
struct LotoNetWidgetEntryView: View {
    let entry: JackpotTimelineProvider.Entry

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

@available(iOS 17.0, *)
struct LotoNetWidget: Widget {
    let kind: String = WidgetConstants.kind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: GameSelectionIntent.self, provider: JackpotTimelineProvider()) { entry in
            LotoNetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Report NET Loto")
        .description("Afiseaza reportul NET estimat pentru Loto 6/49 sau Joker.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
