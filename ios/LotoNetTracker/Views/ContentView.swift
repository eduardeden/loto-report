import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var viewModel = ReportViewModel()
    @AppStorage(CurrencyPreferenceStore.key, store: CurrencyPreferenceStore.defaults)
    private var selectedCurrencyRawValue = DisplayCurrency.eur.rawValue

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let isLargeScreen = proxy.size.width >= 430 || proxy.size.height >= 920
                let horizontalPadding: CGFloat = isLargeScreen ? 18 : 16
                let contentWidth = max(proxy.size.width - horizontalPadding * 2, 0)
                ZStack {
                    AppBackdropView()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: isLargeScreen ? 18 : 14) {
                            topBar(isLargeScreen: isLargeScreen)

                            CurrencySwitchView(selection: currencyBinding)

                            if let report = viewModel.report {
                                SpotlightRow(
                                    report: report,
                                    currency: selectedCurrency,
                                    isLargeScreen: isLargeScreen
                                )
                                GameCardView(
                                    game: .loto649,
                                    metrics: report.metrics(for: .loto649),
                                    fxRate: report.eurRonRate,
                                    currency: selectedCurrency,
                                    isLargeScreen: isLargeScreen
                                )
                                GameCardView(
                                    game: .joker,
                                    metrics: report.metrics(for: .joker),
                                    fxRate: report.eurRonRate,
                                    currency: selectedCurrency,
                                    isLargeScreen: isLargeScreen
                                )
                                sourceInfo(report: report)
                            } else {
                                loadingCard
                            }
                        }
                        .frame(width: contentWidth)
                        .frame(minHeight: max(proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom, 0), alignment: .top)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, proxy.safeAreaInsets.top + 10)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + 22)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .ignoresSafeArea()
                .toolbar(.hidden, for: .navigationBar)
            }
            .refreshable {
                await viewModel.refresh(forceWidgetReload: true)
            }
            .task {
                await viewModel.refresh()
            }
            .onChange(of: selectedCurrencyRawValue) { _ in
                CurrencyPreferenceStore.save(selectedCurrency)
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.kind)
            }
            .alert("Atentie", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.errorMessage = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var selectedCurrency: DisplayCurrency {
        DisplayCurrency(rawValue: selectedCurrencyRawValue) ?? .eur
    }

    private var currencyBinding: Binding<DisplayCurrency> {
        Binding(
            get: { selectedCurrency },
            set: { newValue in
                selectedCurrencyRawValue = newValue.rawValue
                CurrencyPreferenceStore.save(newValue)
            }
        )
    }

    private func topBar(isLargeScreen: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Loto Report")
                    .font(isLargeScreen ? .system(size: 36, weight: .heavy, design: .rounded) : .system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                Text("Brut, Impozit si Net in moneda selectata")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 10)

            Button {
                Task {
                    await viewModel.refresh(forceWidgetReload: true)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: isLargeScreen ? 52 : 46, height: isLargeScreen ? 52 : 46)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
    }

    private func sourceInfo(report: ReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moneda activa: \(selectedCurrency.title)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            Text("Curs BNR: \(DisplayFormatter.fx(report.eurRonRate)) EUR/RON")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
            Text("Ultima actualizare: \(DisplayFormatter.dateTime(report.generatedAtDate))")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.82))

            if report.stale {
                Text("Datele pot fi partial expirate; se afiseaza ultima valoare valida.")
                    .font(.footnote)
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.34))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Se incarca datele...")
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
    }
}

private struct CurrencySwitchView: View {
    @Binding var selection: DisplayCurrency

    var body: some View {
        HStack(spacing: 8) {
            switchButton(emoji: "🇪🇺", title: "EUR", currency: .eur)
            switchButton(emoji: "🇷🇴", title: "RON", currency: .ron)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
    }

    private func switchButton(emoji: String, title: String, currency: DisplayCurrency) -> some View {
        let isActive = selection == currency

        return Button {
            selection = currency
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.headline)
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.28) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? Color.white.opacity(0.42) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GameCardView: View {
    let game: LotoGame
    let metrics: GameMetrics
    let fxRate: Double?
    let currency: DisplayCurrency
    let isLargeScreen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isLargeScreen ? 14 : 12) {
            HStack(spacing: 10) {
                Text(game == .loto649 ? "🍀" : "🤡")
                    .font(.system(size: 18))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(accent.opacity(0.9))
                    )

                Text(game.displayName)
                    .font(isLargeScreen ? .title2.weight(.heavy) : .title3.weight(.heavy))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                if metrics.stale {
                    Text("STALE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(red: 1, green: 0.86, blue: 0.5))
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("NET \(currency.title)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.75))
                Text(DisplayFormatter.money(metrics.amount(for: .net, currency: currency, fxRate: fxRate), currency: currency))
                    .font(isLargeScreen ? .system(size: 36, weight: .heavy, design: .rounded) : .system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            LazyVGrid(columns: gridColumns, spacing: 10) {
                MetricTile(
                    title: "\(MonetaryMetric.gross.title) \(currency.title)",
                    value: DisplayFormatter.money(metrics.amount(for: .gross, currency: currency, fxRate: fxRate), currency: currency)
                )
                MetricTile(
                    title: "\(MonetaryMetric.tax.title) \(currency.title)",
                    value: DisplayFormatter.money(metrics.amount(for: .tax, currency: currency, fxRate: fxRate), currency: currency)
                )
                MetricTile(
                    title: "\(MonetaryMetric.net.title) \(currency.title)",
                    value: DisplayFormatter.money(metrics.amount(for: .net, currency: currency, fxRate: fxRate), currency: currency)
                )
            }
        }
        .padding(isLargeScreen ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderGradient, lineWidth: 1.25)
        )
    }

    private var accent: Color {
        switch game {
        case .loto649:
            return LotteryTheme.loto649
        case .joker:
            return LotteryTheme.joker
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.9), Color.white.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 110), spacing: 10),
            GridItem(.flexible(minimum: 110), spacing: 10)
        ]
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.75))
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct SpotlightRow: View {
    let report: ReportResponse
    let currency: DisplayCurrency
    let isLargeScreen: Bool

    var body: some View {
        HStack(spacing: 12) {
            SpotlightCard(
                title: "6/49 NET \(currency.title)",
                value: DisplayFormatter.money(
                    report.metrics(for: .loto649).amount(for: .net, currency: currency, fxRate: report.eurRonRate),
                    currency: currency
                ),
                accent: LotteryTheme.loto649,
                isLargeScreen: isLargeScreen
            )
            SpotlightCard(
                title: "Joker NET \(currency.title)",
                value: DisplayFormatter.money(
                    report.metrics(for: .joker).amount(for: .net, currency: currency, fxRate: report.eurRonRate),
                    currency: currency
                ),
                accent: LotteryTheme.joker,
                isLargeScreen: isLargeScreen
            )
        }
    }
}

private struct SpotlightCard: View {
    let title: String
    let value: String
    let accent: Color
    let isLargeScreen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.8))
                .lineLimit(1)
            Text(value)
                .font(isLargeScreen ? .system(size: 23, weight: .heavy, design: .rounded) : .system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.45), Color.black.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
        )
    }
}

private struct AppBackdropView: View {
    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.25),
                    Color.black.opacity(0.62),
                    Color(red: 0.06, green: 0.04, blue: 0.12).opacity(0.86)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
}
