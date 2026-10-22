import Foundation

/// A message that renders differently per language. Arguments carry types so
/// numbers can be formatted per-locale (Swiss `1’234`, English `1,234`).
public struct LocalizedMessage: Codable, Hashable, Sendable {
    public let key: L10n.Key
    public let args: [Arg]

    public init(_ key: L10n.Key, _ args: [Arg] = []) {
        self.key = key
        self.args = args
    }

    public enum Arg: Codable, Hashable, Sendable {
        case number(Int)
        case text(String)
        case symbol(String)

        public static func ==(l: Arg, r: Arg) -> Bool {
            switch (l, r) {
            case (.number(let a), .number(let b)): return a == b
            case (.text(let a), .text(let b)): return a == b
            case (.symbol(let a), .symbol(let b)): return a == b
            default: return false
            }
        }
    }
}

/// Application language.
public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case german = "de-CH"

    /// Foundation locale used for number formatting.
    public var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en_US")
        case .german: return Locale(identifier: "de_CH")
        }
    }
}

/// Renders `LocalizedMessage`s and numbers for a language.
public struct Localizer: Sendable {

    public let language: AppLanguage

    public init(language: AppLanguage = .english) {
        self.language = language
    }

    /// Render a localized message. Missing keys fall back to English, then
    /// to the key name itself (loud during development, never a crash).
    public func string(_ message: LocalizedMessage) -> String {
        let template = template(for: message.key)
        return render(template, args: message.args)
    }

    public func string(_ key: L10n.Key, _ args: [LocalizedMessage.Arg] = []) -> String {
        string(LocalizedMessage(key, args))
    }

    /// Number formatting per locale: `1'234` for de-CH, `1,234` for en.
    public func format(_ value: Int) -> String {
        NumberFormatCache.shared.string(value, locale: language.locale)
    }

    /// Template lookup: language table → English table → raw key.
    func template(for key: L10n.Key) -> String {
        let table = language == .german ? GermanStrings.table : EnglishStrings.table
        return table[key] ?? EnglishStrings.table[key] ?? key.rawValue
    }

    private func render(_ template: String, args: [LocalizedMessage.Arg]) -> String {
        var result = template
        for (i, arg) in args.enumerated() {
            let replacement: String
            switch arg {
            case .number(let v): replacement = format(v)
            case .text(let s): replacement = s
            case .symbol(let s): replacement = s
            }
            result = result.replacingOccurrences(of: "{\(i)}", with: replacement)
        }
        return result
    }
}

/// `NumberFormatter` is expensive to create; cache one per locale.
final class NumberFormatCache: @unchecked Sendable {
    static let shared = NumberFormatCache()
    private let lock = NSLock()
    private var formatters: [String: NumberFormatter] = [:]

    func string(_ value: Int, locale: Locale) -> String {
        lock.lock()
        defer { lock.unlock() }
        let key = locale.identifier
        if formatters[key] == nil {
            let f = NumberFormatter()
            f.locale = locale
            f.numberStyle = .decimal
            if locale.identifier == "de_CH" {
                f.groupingSeparator = "’"
            }
            formatters[key] = f
        }
        return formatters[key]!.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
