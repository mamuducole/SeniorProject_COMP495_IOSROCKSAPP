import Foundation

enum DeepLinkRoute: Equatable {
    case event(UUID)
    case chapter(UUID)
    case news(UUID)
    case scholarship(UUID)
    case mentor(UUID)

    init?(url: URL) {
        guard url.scheme == "rocks" else { return nil }
        let routeName = url.host
        let identifier = url.pathComponents.dropFirst().first
        guard let routeName, let identifier, let id = UUID(uuidString: identifier) else { return nil }

        switch routeName {
        case "event": self = .event(id)
        case "chapter": self = .chapter(id)
        case "news": self = .news(id)
        case "scholarship": self = .scholarship(id)
        case "mentor": self = .mentor(id)
        default: return nil
        }
    }
}
