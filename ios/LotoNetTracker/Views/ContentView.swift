import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var viewModel = ReportViewModel()
    @AppStorage(CurrencyPreferenceStore.key, store: CurrencyPreferenceStore.defaults)
    private var selectedCurrencyRawValue = DisplayCurrency.eur.rawValue

    var body: some View {
        GeometryReader { proxy in
            let isLargeScreen = proxy.size.width >= 430 || proxy.size.height >= 900
            let horizontalPadding: CGFloat = isLargeScreen ? 18 : 16

            ZStack {
                AppBackdropView()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: isLargeScreen ? 12 : 10) {
                        topBar(isLargeScreen: isLargeScreen)
                        CurrencySwitchView(selection: currencyBinding)

                        if let report = viewModel.report {
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
                        } else if viewModel.isLoading {
                            loadingCard
                        } else {
                            unavailableCard
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, proxy.safeAreaInsets.top + (isLargeScreen ? 6 : 4))
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color.black)
        .task {
            await viewModel.refresh()
        }
        .onChange(of: selectedCurrencyRawValue) { _ in
            CurrencyPreferenceStore.save(selectedCurrency)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.kind)
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
        HStack(alignment: .center, spacing: 12) {
            Text("Loto Report")
                .font(.system(size: isLargeScreen ? 33 : 29, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)

            Spacer(minLength: 10)

            Button {
                Task {
                    await viewModel.refresh(forceWidgetReload: true)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: isLargeScreen ? 46 : 42, height: isLargeScreen ? 46 : 42)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.32), lineWidth: 1)
                )
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isLargeScreen ? 48 : 44)
    }

    private func sourceInfo(report: ReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            infoRow(title: "Curs BNR:", value: "\(DisplayFormatter.fx(report.eurRonRate)) EUR/RON")
            infoRow(title: "Ultima actualizare:", value: DisplayFormatter.dateTime(report.generatedAtDate))

            if report.stale {
                Text("Date partial expirate. Afisam ultima valoare valida.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.78))
            Spacer(minLength: 8)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Se incarca datele...")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
    }

    private var unavailableCard: some View {
        Text("Nu am putut incarca datele momentan.")
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.black.opacity(0.34))
            )
    }
}

private struct CurrencySwitchView: View {
    @Binding var selection: DisplayCurrency

    var body: some View {
        HStack(spacing: 6) {
            switchButton(emoji: "🇪🇺", title: "EUR", currency: .eur)
            switchButton(emoji: "🇷🇴", title: "RON", currency: .ron)
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private func switchButton(emoji: String, title: String, currency: DisplayCurrency) -> some View {
        let isActive = selection == currency

        return Button {
            selection = currency
        } label: {
            HStack(spacing: 7) {
                Text(emoji)
                    .font(.system(size: 18))
                Text(title)
                    .font(.subheadline.weight(.black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.25) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isActive ? Color.white.opacity(0.38) : Color.clear, lineWidth: 1)
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
        VStack(alignment: .leading, spacing: isLargeScreen ? 11 : 10) {
            HStack(spacing: 10) {
                Text(game == .loto649 ? "🍀" : "🤡")
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.96))
                    )
                    .shadow(color: accent.opacity(0.26), radius: 8, x: 0, y: 4)

                Text(game.displayName)
                    .font(.system(size: isLargeScreen ? 21 : 19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if metrics.stale {
                    Text("STALE")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(red: 1, green: 0.84, blue: 0.46))
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("NET \(currency.title)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.white.opacity(0.76))
                Text(DisplayFormatter.money(metrics.amount(for: .net, currency: currency, fxRate: fxRate), currency: currency))
                    .font(.system(size: isLargeScreen ? 38 : 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, isLargeScreen ? 11 : 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.86), accent.opacity(0.34), Color.white.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )

            HStack(spacing: 8) {
                MetricTile(
                    title: "\(MonetaryMetric.gross.title) \(currency.title)",
                    value: DisplayFormatter.money(metrics.amount(for: .gross, currency: currency, fxRate: fxRate), currency: currency)
                )
                MetricTile(
                    title: "\(MonetaryMetric.tax.title) \(currency.title)",
                    value: DisplayFormatter.money(metrics.amount(for: .tax, currency: currency, fxRate: fxRate), currency: currency)
                )
            }
        }
        .padding(isLargeScreen ? 15 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(borderGradient, lineWidth: 1.15)
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
            colors: [accent.opacity(0.95), Color.white.opacity(0.36)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.72))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.52)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct AppBackdropView: View {
    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.58),
                    Color(red: 0.05, green: 0.035, blue: 0.11).opacity(0.9)
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
