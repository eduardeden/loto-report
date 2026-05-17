import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ReportViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let report = viewModel.report {
                        GameCardView(game: .loto649, metrics: report.metrics(for: .loto649))
                        GameCardView(game: .joker, metrics: report.metrics(for: .joker))
                        sourceInfo(report: report)
                    } else {
                        ProgressView("Se incarca datele...")
                    }
                }
                .padding(16)
            }
            .navigationTitle("Report NET")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.refresh()
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Loto 6/49 + Joker")
                .font(.headline)
            Text("Valori nete estimate in EUR, pe baza reportului brut in RON si a cursului BNR.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func sourceInfo(report: ReportResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Curs EUR/RON: \(DisplayFormatter.fx(report.eurRonRate))")
                .font(.footnote)
            Text("Ultima actualizare: \(DisplayFormatter.dateTime(report.generatedAtDate))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if report.stale {
                Text("Datele pot fi partial expirate; se afiseaza ultima valoare valida.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct GameCardView: View {
    let game: LotoGame
    let metrics: GameMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(game.displayName)
                    .font(.title3.bold())
                Spacer()
                if metrics.stale {
                    Text("STALE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            valueRow("Brut RON", DisplayFormatter.ron(metrics.grossRon))
            valueRow("Impozit RON", DisplayFormatter.ron(metrics.taxRon))
            valueRow("Net RON", DisplayFormatter.ron(metrics.netRon))
            valueRow("Net EUR", DisplayFormatter.eur(metrics.netEur))
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func valueRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}

#Preview {
    ContentView()
}
