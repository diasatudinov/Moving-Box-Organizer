import Foundation

/// What kind of storage place a location is. Affects only the icon and label, never behaviour.
///
/// Stored in SwiftData as its raw `String` (see `StorageLocation.kindRaw`), so unknown values —
/// for example from a backup made by a newer app version — fall back to `.other`.
/// `nonisolated`: it is plain data used by SwiftData models, which are not main-actor isolated.
nonisolated enum LocationKind: String, CaseIterable, Codable, Sendable {
    case room
    case rack
    case shelf
    case cabinet
    case drawer
    case box
    case container
    case other

    init(storedValue: String) {
        self = LocationKind(rawValue: storedValue) ?? .other
    }
}
