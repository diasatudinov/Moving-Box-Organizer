import SwiftUI

/// Accent-tinted tile with the kind's symbol, used in location rows and the kind picker.
/// Scales with Dynamic Type. Decorative: the row's text already names the kind.
struct LocationKindIcon: View {
    let kind: LocationKind
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 32

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: side * 0.5, weight: .medium))
            .foregroundStyle(.tint)
            .frame(width: side, height: side)
            .background(Color.accentTile, in: .rect(cornerRadius: side / 4))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(LocationKind.allCases, id: \.self) { kind in
            LocationKindIcon(kind: kind)
        }
    }
    .padding()
}
