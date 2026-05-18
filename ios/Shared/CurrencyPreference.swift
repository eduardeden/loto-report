import Foundation

enum DisplayCurrency: String, CaseIterable, Identifiable {
    case eur
    case ron

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ron:
            return "RON"
        case .eur:
            return "EUR"
        }
    }
}

enum MonetaryMetric: CaseIterable {
    case gross
    case tax
    case net

    var title: String {
        switch self {
        case .gross:
            return "Brut"
        case .tax:
            return "Impozit"
        case .net:
            return "Net"
        }
    }
}

enum CurrencyPreferenceStore {
    static let key = "selected_display_currency"
    private static let suiteName = "group.com.eduardcramaroc.LotoReport"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func load() -> DisplayCurrency {
        let value = defaults.string(forKey: key) ?? DisplayCurrency.eur.rawValue
        return DisplayCurrency(rawValue: value) ?? .eur
    }

    static func save(_ currency: DisplayCurrency) {
        defaults.set(currency.rawValue, forKey: key)
    }
}

extension GameMetrics {
    func amount(for metric: MonetaryMetric, currency: DisplayCurrency, fxRate: Double?) -> Double? {
        let ronValue: Double?
        switch metric {
        case .gross:
            ronValue = grossRon
        case .tax:
            ronValue = taxRon
        case .net:
            ronValue = netRon
        }

        switch currency {
        case .ron:
            return ronValue
        case .eur:
            if metric == .net, let netEur {
                return netEur
            }
            guard let ronValue, let fxRate, fxRate > 0 else { return nil }
            return ronValue / fxRate
        }
    }
}
