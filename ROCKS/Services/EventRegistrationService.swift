import Foundation

protocol EventRegistrationService: Sendable {
    func register(for event: ROCKSEvent) async throws
    func cancel(for event: ROCKSEvent) async throws
}

actor MockEventRegistrationService: EventRegistrationService {
    private var registeredEventIDs = Set<UUID>()

    func register(for event: ROCKSEvent) async throws {
        guard !registeredEventIDs.contains(event.id) else {
            throw AppError.validation("You are already registered for this event.")
        }
        registeredEventIDs.insert(event.id)
    }

    func cancel(for event: ROCKSEvent) async throws {
        registeredEventIDs.remove(event.id)
    }
}
