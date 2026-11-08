import Foundation

/// Errors of `InventoryService`. Messages are user-facing and localized.
nonisolated enum InventoryError: LocalizedError, Equatable, Sendable {
    case emptyName
    case invalidQuantity
    case locationNotFound
    case itemNotFound
    case moveIntoItself
    case saveFailed

    var errorDescription: String? {
        String(localized: message)
    }

    /// The localizable message; exposed so tests can check translations independently of the device language.
    var message: LocalizedStringResource {
        switch self {
        case .emptyName:
            LocalizedStringResource("Enter a name.", comment: "Validation error: name is empty")
        case .invalidQuantity:
            LocalizedStringResource("Quantity must be at least 1.", comment: "Validation error: quantity below 1")
        case .locationNotFound:
            LocalizedStringResource("This place no longer exists.", comment: "Error: location was deleted")
        case .itemNotFound:
            LocalizedStringResource("This item no longer exists.", comment: "Error: item was deleted")
        case .moveIntoItself:
            LocalizedStringResource("A place can't be moved inside itself.", comment: "Error: moving a location into itself or its own sub-location")
        case .saveFailed:
            LocalizedStringResource("Couldn't save changes. Try again.", comment: "Error: SwiftData save failed")
        }
    }
}
