import SwiftUI

/// Shared button looks. iOS 26+ gets Liquid Glass styles, iOS 18 the classic ones —
/// the only place in the app where the two looks are branched.
extension View {
    /// Filled accent capsule for the main action of a screen.
    /// The label uses `OnAccent`: white text is unreadable on the dark-mode accent (contrast 1.9:1).
    @ViewBuilder
    func primaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .foregroundStyle(Color.onAccent)
        } else {
            self
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .foregroundStyle(Color.onAccent)
        }
    }

    /// Neutral capsule for secondary actions. Uses the label color (not the accent) for enough contrast.
    @ViewBuilder
    func secondaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
        } else {
            self
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(.primary)
        }
    }
}
