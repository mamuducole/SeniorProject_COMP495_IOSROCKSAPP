import Foundation

protocol EventRepository: Sendable {
    func fetchUpcomingEvents() async throws -> [ROCKSEvent]
    func fetchMyEvents() async throws -> [ROCKSEvent]
    func fetchPastEvents() async throws -> [ROCKSEvent]
    func fetchEvent(id: UUID) async throws -> ROCKSEvent?
}

struct MockEventRepository: EventRepository {
    func fetchUpcomingEvents() async throws -> [ROCKSEvent] {
        ROCKSEvent.examples
    }

    func fetchMyEvents() async throws -> [ROCKSEvent] {
        ROCKSEvent.examples.map { event in
            var copy = event
            copy.isRegisteredByCurrentUser = true
            return copy
        }
    }

    func fetchPastEvents() async throws -> [ROCKSEvent] {
        ROCKSEvent.pastExamples
    }

    func fetchEvent(id: UUID) async throws -> ROCKSEvent? {
        (ROCKSEvent.examples + ROCKSEvent.pastExamples).first { $0.id == id }
    }
}
