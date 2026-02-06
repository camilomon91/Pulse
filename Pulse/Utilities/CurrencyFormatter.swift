import Foundation

enum CurrencyFormatter {
    private static var formatters: [String: NumberFormatter] = [:]

    static func string(cents: Int, currency: String) -> String {
        let amount = Double(cents) / 100.0
        let formatter = formatter(for: currency)
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }

    private static func formatter(for currency: String) -> NumberFormatter {
        if let formatter = formatters[currency] {
            return formatter
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatters[currency] = formatter
        return formatter
    }
}
