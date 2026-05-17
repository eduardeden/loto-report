import SwiftUI
import WidgetKit

struct JackpotEntry: TimelineEntry {
    let date: Date
    let report: ReportResponse?
}

struct JackpotTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> JackpotEntry {
        JackpotEntry(date: Date(), report: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (JackpotEntry) -> Void) {
        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JackpotEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let refreshDate = nextRefreshDate(from: entry.report)
            completion(Timeline(entries: [entry], policy: .after(refreshDate)))
        }
    }

    private func loadEntry() async -> JackpotEntry {
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

        return JackpotEntry(date: Date(), report: report)
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

struct LotoNetWidgetEntryView: View {
    let entry: JackpotEntry

    var body: some View {
        let loto = entry.report?.metrics(for: .loto649)
        let joker = entry.report?.metrics(for: .joker)

        VStack(alignment: .leading, spacing: 6) {
            Text("Loto Report")
                .font(.headline)

            HStack {
                Text("6/49")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DisplayFormatter.eur(loto?.netEur))
                    .font(.caption.bold())
            }

            HStack {
                Text("Joker")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DisplayFormatter.eur(joker?.netEur))
                    .font(.caption.bold())
            }

            Divider()

            HStack {
                Text("Curs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DisplayFormatter.fx(entry.report?.eurRonRate))
                    .font(.caption2)
            }
        }
        .padding(12)
    }
}

struct LotoNetWidget: Widget {
    let kind: String = WidgetConstants.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JackpotTimelineProvider()) { entry in
            LotoNetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Report NET Loto")
        .description("Afiseaza reportul NET pentru Loto 6/49 si Joker.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
