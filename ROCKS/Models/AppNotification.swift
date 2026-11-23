import Foundation

struct AppNotification: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let body: String?
    /// A `rocks://` deep link path resolved when the notification is opened.
    let routePath: String?
    var isRead: Bool
    let createdAt: Date

    var route: DeepLinkRoute? {
        guard let routePath, let url = URL(string: routePath) else { return nil }
        return DeepLinkRoute(url: url)
    }

    static let examples = [
        AppNotification(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000001") ?? UUID(),
            title: "Mentorship request update",
            body: "Kevin Roberts is reviewing your mentorship request.",
            routePath: nil,
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now
        ),
        AppNotification(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000002") ?? UUID(),
            title: "Event reminder",
            body: "ROCKS Mentorship Mixer starts in 12 days.",
            routePath: "rocks://event/10000000-0000-0000-0000-000000000002",
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .hour, value: -8, to: .now) ?? .now
        ),
        AppNotification(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000003") ?? UUID(),
            title: "Scholarship deadline approaching",
            body: "The ROCKS National Scholarship deadline is coming up.",
            routePath: nil,
            isRead: false,
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        ),
        AppNotification(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000004") ?? UUID(),
            title: "Welcome to the community",
            body: "Complete your profile to connect with your chapter.",
            routePath: nil,
            isRead: true,
            createdAt: Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now
        )
    ]
}
