import Foundation
import Observation

enum EventsTab: CaseIterable, Hashable {
    case upcoming
    case myEvents
    case past

    var title: String {
        switch self {
        case .upcoming: "Upcoming"
        case .myEvents: "My Events"
        case .past: "Past Events"
        }
    }
}

@MainActor
@Observable
final class EventsViewModel {
    var selectedTab: EventsTab = .upcoming

    private(set) var upcoming: [ROCKSEvent] = []
    private(set) var mine: [ROCKSEvent] = []
    private(set) var past: [ROCKSEvent] = []
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?
    var errorMessage: String?

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var visibleEvents: [ROCKSEvent] {
        switch selectedTab {
        case .upcoming: upcoming
        case .myEvents: mine
        case .past: past
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let upcomingEvents = environment.eventRepository.fetchUpcomingEvents()
        async let myEvents = environment.eventRepository.fetchMyEvents()
        async let pastEvents = environment.eventRepository.fetchPastEvents()

        do {
            upcoming = Self.deduped(try await upcomingEvents)
            mine = Self.deduped((try? await myEvents) ?? [])
            past = Self.deduped((try? await pastEvents) ?? [])
            lastUpdated = .now
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load events right now."
        }
    }

    /// Removes duplicate events by id, preserving order.
    private static func deduped(_ events: [ROCKSEvent]) -> [ROCKSEvent] {
        var seen = Set<UUID>()
        return events.filter { seen.insert($0.id).inserted }
    }

    func toggleRegistration(for event: ROCKSEvent) async {
        do {
            if event.isRegisteredByCurrentUser {
                try await environment.eventRegistrationService.cancel(for: event)
            } else {
                try await environment.eventRegistrationService.register(for: event)
            }
            applyRegistration(!event.isRegisteredByCurrentUser, to: event.id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update your registration."
        }
    }

    private func applyRegistration(_ registered: Bool, to eventID: UUID) {
        func update(_ events: inout [ROCKSEvent]) {
            guard let index = events.firstIndex(where: { $0.id == eventID }) else { return }
            events[index].isRegisteredByCurrentUser = registered
        }
        update(&upcoming)
        update(&mine)
        update(&past)
        if registered, let event = upcoming.first(where: { $0.id == eventID }), !mine.contains(where: { $0.id == eventID }) {
            mine.append(event)
            mine.sort { $0.startsAt < $1.startsAt }
        }
        if !registered {
            mine.removeAll { $0.id == eventID }
        }
    }
}
