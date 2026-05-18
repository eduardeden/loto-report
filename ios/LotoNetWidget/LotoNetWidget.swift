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
        VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 10) {
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
        HStack(spacing: 6) {
            Text("Loto Report")
                .font(.system(size: family == .systemSmall ? 11 : 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(currencyEmoji) \(currency.title)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
        }
    }

    private var smallLayout: some View {
        VStack(spacing: 7) {
            netPill(title: "🍀 6/49", metrics: lotoMetrics, accent: LotteryTheme.loto649, compact: true)
            netPill(title: "🤡 Joker", metrics: jokerMetrics, accent: LotteryTheme.joker, compact: true)
        }
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                netPill(title: "🍀 Loto 6/49", metrics: lotoMetrics, accent: LotteryTheme.loto649, compact: false)
                netPill(title: "🤡 Joker", metrics: jokerMetrics, accent: LotteryTheme.joker, compact: false)
            }

            HStack(spacing: 6) {
                Text("Curs BNR")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.75))
                Spacer(minLength: 6)
                Text(DisplayFormatter.fx(entry.report?.eurRonRate))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
    }

    private func netPill(title: String, metrics: GameMetrics?, accent: Color, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: compact ? 11 : 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("NET")
                    .font(.system(size: compact ? 8 : 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))
            }

            Text(formattedNet(metrics))
                .font(.system(size: compact ? 18 : 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(compact ? 0.5 : 0.58)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 7 : 10)
        .background(
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.82), accent.opacity(0.32), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
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

    private func formattedNet(_ metrics: GameMetrics?) -> String {
        let value = metrics?.amount(for: .net, currency: currency, fxRate: entry.report?.eurRonRate)
        return DisplayFormatter.wholeMoney(value, currency: currency)
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
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.62),
                    Color(red: 0.05, green: 0.025, blue: 0.11).opacity(0.84)
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
