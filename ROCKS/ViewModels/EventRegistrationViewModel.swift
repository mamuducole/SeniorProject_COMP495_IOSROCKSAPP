import Foundation
import Observation

@MainActor
@Observable
final class EventRegistrationViewModel {
    var isRegistered = false
    var isLoading = false
    var errorMessage: String?

    private let service: any EventRegistrationService

    init(service: any EventRegistrationService) {
        self.service = service
    }

    func toggleRegistration(for event: ROCKSEvent) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if isRegistered {
                try await service.cancel(for: event)
                isRegistered = false
            } else {
                try await service.register(for: event)
                isRegistered = true
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update your registration."
        }
    }
}
