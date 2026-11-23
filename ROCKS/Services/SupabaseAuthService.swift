import Foundation
import Supabase

/// Builds the shared Supabase client from app configuration.
enum SupabaseClientProvider {
    static let options = SupabaseClientOptions(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )

    static func makeClient(configuration: AppConfiguration) -> SupabaseClient? {
        guard let url = configuration.supabaseURL,
              let key = configuration.supabaseAnonKey,
              !key.isEmpty else { return nil }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: options
        )
    }
}

final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentUser() async throws -> AuthUser? {
        let session: Session
        do {
            session = try await client.auth.session
        } catch AuthError.sessionMissing {
            return nil
        } catch {
            guard isRejectedStoredSession(error) else {
                throw AppError.network(error)
            }
            do {
                try await client.auth.signOut(scope: .local)
            } catch {
                throw AppError.network(error)
            }
            return nil
        }

        guard !session.isExpired else {
            throw AppError.unauthenticated
        }

        do {
            return try await authUser(for: session.user.id, email: session.user.email ?? "")
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.network(error)
        }
    }

    func authStateChanges() async -> AsyncStream<AuthSessionChange> {
        let changes = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await (event, _) in changes {
                    switch event {
                    case .signedOut, .userDeleted:
                        continuation.yield(.signedOut)
                    case .tokenRefreshed:
                        continuation.yield(.sessionRefreshed)
                    default:
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        guard !email.isEmpty, !password.isEmpty else {
            throw AppError.validation("Enter your email and password.")
        }
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return try await authUser(for: session.user.id, email: session.user.email ?? email.lowercased())
        } catch let error as AppError {
            throw error
        } catch let error as AuthError {
            switch error {
            case .api(_, .invalidCredentials, _, _):
                throw AppError.validation("The email or password is incorrect.")
            case .api(_, .emailNotConfirmed, _, _):
                throw AppError.validation("Confirm your email before signing in.")
            default:
                throw AppError.validation("Sign-in could not be completed. Please try again.")
            }
        } catch {
            throw AppError.network(error)
        }
    }

    /// Creates an Auth user. The database trigger creates a pending, non-privileged profile;
    /// membership is approved only by an administrator.
    func signUp(_ registration: RegistrationRequest) async throws -> SignUpResult {
        let email = registration.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard registration.acceptedAcknowledgment else {
            throw AppError.validation("Review and accept the acknowledgment to continue.")
        }
        var metadata: [String: AnyJSON] = [
            "first_name": .string(registration.firstName.trimmingCharacters(in: .whitespacesAndNewlines)),
            "last_name": .string(registration.lastName.trimmingCharacters(in: .whitespacesAndNewlines)),
            "terms_accepted": .string("true"),
            "terms_version": .string(RegistrationRequest.acknowledgmentVersion)
        ]
        if let chapterID = registration.requestedChapterID {
            metadata["requested_chapter_id"] = .string(chapterID.uuidString)
        }
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: registration.password,
                data: metadata,
                redirectTo: AuthCallbackLink.redirectURL
            )
            // With confirmations enabled, an existing address also returns a user without a
            // session; the same message is shown so registration does not reveal accounts.
            guard let session = response.session else {
                return .confirmationRequired(email: email)
            }
            return .signedIn(try await authUser(for: session.user.id, email: session.user.email ?? email))
        } catch let error as AppError {
            throw error
        } catch let error as AuthError {
            throw Self.registrationError(error)
        } catch {
            throw AppError.network(error)
        }
    }

    func completeEmailConfirmation(url: URL) async throws -> AuthUser {
        guard AuthCallbackLink.matches(url) else {
            throw AppError.validation("This confirmation link is invalid.")
        }
        do {
            let session = try await client.auth.session(from: url)
            guard !session.isExpired else { throw AppError.unauthenticated }
            return try await authUser(for: session.user.id, email: session.user.email ?? "")
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            throw AppError.network(error)
        } catch {
            throw AppError.validation("This confirmation link is invalid or expired. Sign in, or request a new link by registering again on this device.")
        }
    }

    func deleteAccount() async throws {
        do {
            try await client.rpc("delete_own_account").execute()
        } catch let error as PostgrestError where error.code == "42501" {
            throw AppError.validation(error.message.contains("last national administrator")
                ? "Assign another national administrator before deleting this account."
                : "You must be signed in to delete your account.")
        } catch let error as URLError {
            throw AppError.network(error)
        } catch {
            throw AppError.database("Your account could not be deleted. Please try again.")
        }
        // The server session is invalid once the user is deleted; clear it locally.
        try? await client.auth.signOut(scope: .local)
    }

    static func registrationError(_ error: AuthError) -> AppError {
        switch error.errorCode {
        case .weakPassword:
            return .validation("Choose a stronger password. Use at least 8 characters with a mix of letters and numbers.")
        case .overEmailSendRateLimit, .overRequestRateLimit:
            return .validation("Too many requests. Please wait a few minutes and try again.")
        case .signupDisabled, .emailProviderDisabled:
            return .configuration("Account registration is currently closed.")
        case ErrorCode("email_address_invalid"), .emailAddressNotAuthorized, .validationFailed:
            return .validation("This email address cannot be used to register. Check it and try again.")
        case .userAlreadyExists, .emailExists:
            return .validation("An account may already exist for this email. Sign in or reset your password.")
        default:
            return .validation("Registration could not be completed. Please try again.")
        }
    }

    func requestPasswordReset(email: String) async throws {
        guard email.contains("@") else {
            throw AppError.validation("Enter the email address associated with your account.")
        }
        do {
            try await client.auth.resetPasswordForEmail(email, redirectTo: PasswordRecoveryLink.redirectURL)
        } catch AuthError.api(_, .overEmailSendRateLimit, _, _) {
            throw AppError.validation("Too many email requests. Please wait and try again.")
        } catch AuthError.api(_, .emailProviderDisabled, _, _) {
            throw AppError.configuration("Password recovery email is unavailable in this environment.")
        } catch is AuthError {
            throw AppError.validation("Unable to request password recovery. Please try again.")
        } catch {
            throw AppError.network(error)
        }
    }

    func openPasswordRecovery(url: URL) async throws {
        guard PasswordRecoveryLink.matches(url) else {
            throw AppError.validation("This password recovery link is invalid.")
        }
        do {
            let session = try await client.auth.session(from: url)
            guard !session.isExpired else {
                throw AppError.validation("This password recovery link has expired. Request a new one.")
            }
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            throw AppError.network(error)
        } catch {
            throw AppError.validation("This password recovery link is invalid or expired. Request a new one on the same device.")
        }
    }

    func updatePassword(_ password: String) async throws {
        guard password.count >= 8 else {
            throw AppError.validation("Use at least 8 characters for your password.")
        }
        do {
            _ = try await client.auth.update(user: UserAttributes(password: password))
        } catch AuthError.weakPassword {
            throw AppError.validation("This password does not meet the server's security requirements.")
        } catch AuthError.api(_, .weakPassword, _, _) {
            throw AppError.validation("This password does not meet the server's security requirements.")
        } catch AuthError.api(_, .samePassword, _, _) {
            throw AppError.validation("Choose a password different from your current password.")
        } catch AuthError.api(_, .sessionExpired, _, _) {
            throw AppError.validation("Your recovery session expired. Request a new link.")
        } catch {
            throw AppError.network(error)
        }
    }

    func closePasswordRecovery() async throws {
        do {
            try await client.auth.signOut(scope: .local)
        } catch {
            throw AppError.network(error)
        }
    }

    func signOut() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            throw AppError.network(error)
        }
    }

    /// Reads the server-owned role and membership status. Unknown values fail closed.
    private func authUser(for userID: UUID, email: String) async throws -> AuthUser {
        struct AccessRow: Decodable {
            let role: String
            let membershipStatus: String

            enum CodingKeys: String, CodingKey {
                case role
                case membershipStatus = "membership_status"
            }
        }
        let row: AccessRow = try await client
            .from("profiles")
            .select("role, membership_status")
            .eq("id", value: userID.uuidString)
            .single()
            .execute()
            .value
        guard let role = AppRole(rawValue: row.role),
              let status = MembershipStatus(rawValue: row.membershipStatus) else {
            throw AppError.invalidResponse
        }
        return AuthUser(id: userID, email: email, role: role, membershipStatus: status)
    }

    private func isRejectedStoredSession(_ error: Error) -> Bool {
        guard let error = error as? AuthError else { return false }
        switch error {
        case .api(_, let errorCode, _, _):
            return [
                .refreshTokenNotFound,
                .refreshTokenAlreadyUsed,
                .sessionNotFound,
                .sessionExpired,
                .userNotFound
            ].contains(errorCode)
        case .jwtVerificationFailed:
            return true
        default:
            return false
        }
    }
}

final class SupabaseEventRegistrationService: EventRegistrationService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func register(for event: ROCKSEvent) async throws {
        guard let userID = client.auth.currentUser?.id else { throw AppError.unauthenticated }
        struct RegistrationInsert: Encodable {
            let eventID: UUID
            let profileID: UUID

            enum CodingKeys: String, CodingKey {
                case eventID = "event_id"
                case profileID = "profile_id"
            }
        }
        do {
            try await client
                .from("event_registrations")
                .insert(RegistrationInsert(eventID: event.id, profileID: userID))
                .execute()
        } catch {
            throw AppError.database("Unable to register for this event right now.")
        }
    }

    func cancel(for event: ROCKSEvent) async throws {
        guard let userID = client.auth.currentUser?.id else { throw AppError.unauthenticated }
        do {
            try await client
                .from("event_registrations")
                .delete()
                .eq("event_id", value: event.id.uuidString)
                .eq("profile_id", value: userID.uuidString)
                .execute()
        } catch {
            throw AppError.database("Unable to cancel your registration right now.")
        }
    }
}
