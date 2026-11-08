import Foundation

/// Display-ready location row. Views get these, never SwiftData models.
struct LocationRowData: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let kind: LocationKind
}

/// Display-ready item row.
struct ItemRowData: Identifiable, Equatable {
    let id: UUID
    let title: String
    let note: String?
    let quantityText: String?
    /// What VoiceOver reads instead of "×2": "Quantity: 2".
    var quantityAccessibilityText: String? = nil
}

extension LocationRowData {
    init(_ location: StorageLocation, inventory: InventoryService, formatter: ContentsFormatter) {
        self.init(
            id: location.id,
            title: location.name,
            subtitle: formatter.summary(inventory.rowContents(of: location)),
            kind: location.kind
        )
    }
}

extension ItemRowData {
    init(_ item: Item, locale: Locale = .current) {
        let number = item.quantity.map { $0.formatted(.number.locale(locale)) }
        self.init(
            id: item.id,
            title: item.name,
            note: item.note,
            quantityText: number.map { "×" + $0 },
            quantityAccessibilityText: number.map {
                String(localized: LocalizedStringResource("Quantity: \($0)", locale: locale, comment: "VoiceOver: item quantity; the argument is a number"))
            }
        )
    }
}
