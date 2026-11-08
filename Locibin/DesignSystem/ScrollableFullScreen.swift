import SwiftUI

/// Centers its content on screen, but scrolls when the content is taller —
/// so empty states and error screens keep their buttons reachable at the largest Dynamic Type sizes.
struct ScrollableFullScreen<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content()
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

extension View {
    /// Description text in empty and error states (see `Color.secondaryText`).
    func emptyStateDescriptionStyle() -> some View {
        foregroundStyle(Color.secondaryText)
    }
}
