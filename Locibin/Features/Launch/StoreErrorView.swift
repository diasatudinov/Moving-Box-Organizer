import SwiftUI

/// Shown when the data store cannot be opened. Data is never deleted from here:
/// "Start Over" only moves the old file aside after a confirmation.
struct StoreErrorView: View {
    let onRetry: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        ScrollableFullScreen {
            ContentUnavailableView {
                Label("Can't Open Your Data", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text("Your saved places and items couldn't be loaded. Try again. If it keeps happening, you can start over — the old data file will be kept in a separate folder.")
                    .emptyStateDescriptionStyle()
            } actions: {
                Button("Try Again", action: onRetry)
                    .primaryButtonStyle()
                Button("Start Over", role: .destructive, action: onStartOver)
                    .secondaryButtonStyle()
            }
        }
    }
}

#Preview {
    StoreErrorView(onRetry: {}, onStartOver: {})
}
