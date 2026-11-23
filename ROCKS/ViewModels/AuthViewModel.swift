import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var firstName = ""
    var lastName = ""
    var confirmPassword = ""
    var requestedChapterID: UUID?
    var acceptedAcknowledgment = false
    var isLoading = false
    var errorMessage: String?

    private let authService: any AuthService

    init(authService: any AuthService) {
        self.authService = authService
    }

    func signIn() async -> AuthUser? {
        guard validateEmail() else { return nil }
        guard !password.isEmpty else {
            errorMessage = "Enter your password."
            return nil
        }
        return await authenticate { [authService] in
            try await authService.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        }
    }

    func signUp() async -> SignUpResult? {
        guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Enter your first and last name."
            return nil
        }
        guard validateEmail() else { return nil }
        guard password.count >= 8 else {
            errorMessage = "Use at least 8 characters for your password."
            return nil
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return nil
        }
        guard acceptedAcknowledgment else {
            errorMessage = "Review and accept the acknowledgment to continue."
            return nil
        }
        let request = RegistrationRequest(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            requestedChapterID: requestedChapterID,
            acceptedAcknowledgment: acceptedAcknowledgment
        )
        return await perform(failureMessage: "Unable to create your account right now.") { [authService] in
            try await authService.signUp(request)
        }
    }

    func requestPasswordReset() async -> Bool {
        guard !isLoading else { return false }
        guard validateEmail() else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authService.requestPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to send a reset email right now."
            return false
        }
    }

    private func validateEmail() -> Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty,
              parts[1].contains("."), !parts[1].hasPrefix("."), !parts[1].hasSuffix("."),
              !parts[1].contains(".."),
              !value.contains(where: \.isWhitespace) else {
            errorMessage = "Enter a valid email address."
            return false
        }
        return true
    }

    private func authenticate(_ operation: () async throws -> AuthUser) async -> AuthUser? {
        await perform(failureMessage: "Unable to sign in right now.", operation)
    }

    private func perform<Result>(failureMessage: String, _ operation: () async throws -> Result) async -> Result? {
        guard !isLoading else { return nil }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            return try await operation()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? failureMessage
            return nil
        }
    }
}
