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
    @Environment(\.widgetFamily) private var family
    let entry: JackpotEntry

    var body: some View {
        Group {
            if #available(iOSApplicationExtension 17.0, *) {
                widgetContent
                    .containerBackground(for: .widget) {
                        WidgetBackgroundView()
                    }
            } else {
                widgetContent
                    .background(WidgetBackgroundView())
            }
        }
    }

    private var widgetContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .padding(family == .systemSmall ? 9 : 12)
    }

    private var headerRow: some View {
        HStack {
            Label("Loto Report", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text("\(currencyEmoji) \(currency.title)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
            if isStale {
                Text("STALE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(red: 1, green: 0.84, blue: 0.52))
                    .clipShape(Capsule())
            }
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 5) {
            smallGameBlock(title: "🍀 6/49", metrics: lotoMetrics, accent: LotteryTheme.loto649)
            smallGameBlock(title: "🤡 Joker", metrics: jokerMetrics, accent: LotteryTheme.joker)
        }
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                compactTile(title: "🍀 Loto 6/49", metrics: lotoMetrics, accent: LotteryTheme.loto649)
                compactTile(title: "🤡 Joker", metrics: jokerMetrics, accent: LotteryTheme.joker)
            }

            HStack {
                Text("Curs BNR")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.8))
                Spacer()
                Text(DisplayFormatter.fx(entry.report?.eurRonRate))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private func widgetValueRow(title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
    }

    private func smallGameBlock(title: String, metrics: GameMetrics?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            widgetValueRow(title: "B", value: formattedAmount(metrics, metric: .gross), accent: accent)
            widgetValueRow(title: "I", value: formattedAmount(metrics, metric: .tax), accent: accent)
            widgetValueRow(title: "N", value: formattedAmount(metrics, metric: .net), accent: accent)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(accent.opacity(0.22))
        )
    }

    private func compactTile(title: String, metrics: GameMetrics?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(1)
            widgetValueRow(title: MonetaryMetric.gross.title, value: formattedAmount(metrics, metric: .gross), accent: accent)
            widgetValueRow(title: MonetaryMetric.tax.title, value: formattedAmount(metrics, metric: .tax), accent: accent)
            widgetValueRow(title: MonetaryMetric.net.title, value: formattedAmount(metrics, metric: .net), accent: accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.45), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var lotoMetrics: GameMetrics? {
        entry.report?.metrics(for: .loto649)
    }

    private var jokerMetrics: GameMetrics? {
        entry.report?.metrics(for: .joker)
    }

    private var currency: DisplayCurrency {
        CurrencyPreferenceStore.load()
    }

    private var currencyEmoji: String {
        switch currency {
        case .ron:
            return "🇷🇴"
        case .eur:
            return "🇪🇺"
        }
    }

    private func formattedAmount(_ metrics: GameMetrics?, metric: MonetaryMetric) -> String {
        let value = metrics?.amount(for: metric, currency: currency, fxRate: entry.report?.eurRonRate)
        return DisplayFormatter.wholeMoney(value, currency: currency)
    }

    private var isStale: Bool {
        guard let report = entry.report else { return true }
        return report.stale || report.metrics(for: .loto649).stale || report.metrics(for: .joker).stale
    }
}

private struct WidgetBackgroundView: View {
    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.64),
                    Color(red: 0.06, green: 0.03, blue: 0.14).opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
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
        .contentMarginsDisabled()
    }
}
