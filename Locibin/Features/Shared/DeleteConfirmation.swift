import Foundation

/// The delete confirmation from the design (Stage 2.4): names the location and says
/// how much will be deleted with it, so nothing disappears by surprise.
enum DeleteConfirmation {
    static func location(
        named name: String,
        contents: LocationContents,
        formatter: ContentsFormatter,
        onDelete: @escaping () -> Void
    ) -> AlertState {
        let message: String
        if contents.locations == 0 && contents.items == 0 {
            message = String(localized: "This can't be undone.", comment: "Delete confirmation message for an empty location")
        } else {
            let summary = formatter.summary(contents)
            message = String(localized: "It contains \(summary). Everything inside will be deleted too. This can't be undone.", comment: "Delete confirmation message; the argument is like '2 places · 16 items'")
        }
        return AlertState(
            title: String(localized: "Delete “\(name)”?", comment: "Delete confirmation title; the argument is the location name"),
            message: message,
            actions: [
                .cancel(),
                AlertState.Action(title: String(localized: "Delete", comment: "Destructive button"), role: .destructive, handler: onDelete),
            ]
        )
    }
}
