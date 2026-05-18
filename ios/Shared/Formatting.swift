import Foundation

enum DisplayFormatter {
    private static let ronFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RON"
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "ro_RO")
        return formatter
    }()

    private static let eurFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "ro_RO")
        return formatter
    }()

    private static let plainFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        formatter.locale = Locale(identifier: "ro_RO")
        return formatter
    }()

    static func ron(_ value: Double?) -> String {
        guard let value else { return "-" }
        return ronFormatter.string(from: NSNumber(value: value)) ?? "-"
    }

    static func eur(_ value: Double?) -> String {
        guard let value else { return "-" }
        return eurFormatter.string(from: NSNumber(value: value)) ?? "-"
    }

    static func fx(_ value: Double?) -> String {
        guard let value else { return "-" }
        return plainFormatter.string(from: NSNumber(value: value)) ?? "-"
    }

    static func money(_ value: Double?, currency: DisplayCurrency) -> String {
        switch currency {
        case .ron:
            return ron(value)
        case .eur:
            return eur(value)
        }
    }

    static func dateTime(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
