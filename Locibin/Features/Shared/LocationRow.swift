import SwiftUI

/// A location in a list: kind icon, name and what is inside.
struct LocationRow: View {
    let row: LocationRowData

    var body: some View {
        HStack(spacing: 12) {
            LocationKindIcon(kind: row.kind)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.body)
                Text(row.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// An item in a list: name, optional note and quantity.
struct ItemRow: View {
    let row: ItemRowData

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let note = row.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let quantity = row.quantityText {
                Text(quantity)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityLabel(row.quantityAccessibilityText ?? quantity)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
