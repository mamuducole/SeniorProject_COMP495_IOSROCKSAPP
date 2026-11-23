import Foundation
import Observation

@MainActor
@Observable
final class NotificationsViewModel {
    private(set) var notifications: [AppNotification] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            notifications = try await environment.notificationRepository.fetchNotifications()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load notifications right now."
        }
    }

    func markAllRead() async {
        let previous = notifications
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        do {
            try await environment.notificationRepository.markAllRead()
        } catch {
            notifications = previous
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update notifications."
        }
    }

    func markRead(_ notification: AppNotification) async {
        guard !notification.isRead,
              let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
        do {
            try await environment.notificationRepository.markRead(id: notification.id)
        } catch {
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].isRead = false
            }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update this notification."
        }
    }
}
