import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private(set) var isLoading = false
    var errorMessage: String?

    private(set) var upcomingEventCount = 0
    private(set) var unreadNotificationCount = 0
    private(set) var mentorshipRequestCount = 0
    private(set) var scholarshipDeadlineCount = 0

    private(set) var featuredEvent: ROCKSEvent?
    private(set) var featuredArticle: NewsArticle?

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    func greeting(for member: MemberProfile?) -> String {
        let name = member?.firstName ?? "Member"
        return "\(greetingTitle), \(name)"
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let events = environment.eventRepository.fetchUpcomingEvents()
        async let notifications = environment.notificationRepository.unreadCount()
        async let requests = environment.mentorshipRepository.fetchRequests()
        async let scholarships = environment.scholarshipRepository.upcomingDeadlineCount()
        async let news = environment.newsRepository.fetchLatestNews()

        do {
            let fetchedEvents = try await events
            upcomingEventCount = fetchedEvents.count
            // Prefer an event that has its own artwork so the featured card's
            // image and title always describe the same event.
            featuredEvent = fetchedEvents.first { $0.imageName != nil || $0.imageURL != nil } ?? fetchedEvents.first
        } catch {
            upcomingEventCount = 0
        }

        unreadNotificationCount = (try? await notifications) ?? 0
        mentorshipRequestCount = ((try? await requests) ?? []).filter { $0.status == .pending }.count
        scholarshipDeadlineCount = (try? await scholarships) ?? 0
        if let articles = try? await news {
            featuredArticle = articles.first { $0.isFeatured } ?? articles.first
        }
    }

    func refreshUnreadCount() async {
        unreadNotificationCount = (try? await environment.notificationRepository.unreadCount()) ?? unreadNotificationCount
    }
}
