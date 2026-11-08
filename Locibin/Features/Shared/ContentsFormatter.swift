import Foundation

/// Turns counts into display text such as "4 places · 37 items" with correct plural forms
/// ("1 место / 2 места / 5 мест"). Plural rules live in the String Catalog.
struct ContentsFormatter {
    let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func places(_ count: Int) -> String {
        text(LocalizedStringResource("\(count) places", locale: locale, comment: "Number of storage places, e.g. in a row subtitle"))
    }

    func items(_ count: Int) -> String {
        text(LocalizedStringResource("\(count) items", locale: locale, comment: "Number of stored items, e.g. in a row subtitle"))
    }

    /// "4 places · 37 items", "4 places", "37 items" or "Empty".
    func summary(_ contents: LocationContents) -> String {
        var parts: [String] = []
        if contents.locations > 0 { parts.append(places(contents.locations)) }
        if contents.items > 0 { parts.append(items(contents.items)) }
        guard !parts.isEmpty else {
            return text(LocalizedStringResource("Empty", locale: locale, comment: "Row subtitle of a location with nothing inside"))
        }
        return parts.joined(separator: " · ")
    }

    private func text(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }
}
