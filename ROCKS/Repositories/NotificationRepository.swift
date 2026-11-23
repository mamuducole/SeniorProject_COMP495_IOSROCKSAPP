import Foundation

protocol NotificationRepository: Sendable {
    func fetchNotifications() async throws -> [AppNotification]
    func markAllRead() async throws
    func markRead(id: UUID) async throws
}

extension NotificationRepository {
    func unreadCount() async throws -> Int {
        try await fetchNotifications().filter { !$0.isRead }.count
    }
}

actor MockNotificationRepository: NotificationRepository {
    private var notifications: [AppNotification] = AppNotification.examples

    func fetchNotifications() async throws -> [AppNotification] {
        notifications.sorted { $0.createdAt > $1.createdAt }
    }

    func markAllRead() async throws {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
    }

    func markRead(id: UUID) async throws {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isRead = true
    }
}
