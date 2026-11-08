import Foundation

extension LocationKind {
    /// SF Symbol for the kind. Names were checked to exist (Stage 3); `LocationKindDisplayTests` re-checks them on iOS.
    var symbolName: String {
        switch self {
        case .room: "house"
        case .rack: "books.vertical"
        case .shelf: "rectangle.split.3x1"
        case .cabinet: "cabinet"
        case .drawer: "tray"
        case .box: "shippingbox"
        case .container: "archivebox"
        case .other: "square.dashed"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .room: LocalizedStringResource("Room", comment: "Location kind: a room, e.g. garage or pantry")
        case .rack: LocalizedStringResource("Rack", comment: "Location kind: shelving unit / rack")
        case .shelf: LocalizedStringResource("Shelf", comment: "Location kind: a single shelf")
        case .cabinet: LocalizedStringResource("Cabinet", comment: "Location kind: cabinet or wardrobe")
        case .drawer: LocalizedStringResource("Drawer", comment: "Location kind: drawer")
        case .box: LocalizedStringResource("Box", comment: "Location kind: box")
        case .container: LocalizedStringResource("Container", comment: "Location kind: plastic container or bin")
        case .other: LocalizedStringResource("Other", comment: "Location kind: anything else")
        }
    }
}
