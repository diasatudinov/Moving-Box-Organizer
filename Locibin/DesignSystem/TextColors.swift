import SwiftUI

extension Color {
    /// Secondary text (paths, counts, notes, captions). Replaces the system `.secondary`,
    /// whose small text measured just under 4.5:1 on dark list rows in the accessibility audit.
    /// 75% of the primary text color: ≈ 8:1 in dark mode and ≈ 10:1 in light mode.
    static var secondaryText: Color { .primary.opacity(0.75) }
}

/// List section header with the app's secondary text color (system headers measured just under 4.5:1).
struct SectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .foregroundStyle(Color.secondaryText)
    }
}
