import Foundation
import Security

protocol AuthService: Sendable {
    func currentUser() async throws -> AuthUser?
    func signIn(email: String, password: String) async throws -> AuthUser
    func signUp(_ registration: RegistrationRequest) async throws -> SignUpResult
    func requestPasswordReset(email: String) async throws
    func openPasswordRecovery(url: URL) async throws
    func updatePassword(_ password: String) async throws
    func closePasswordRecovery() async throws
    func completeEmailConfirmation(url: URL) async throws -> AuthUser
    func deleteAccount() async throws
    func signOut() async throws
    func authStateChanges() async -> AsyncStream<AuthSessionChange>
}

/// Data submitted when an applicant creates an account. Membership is never approved by signup.
struct RegistrationRequest: Sendable, Equatable {
    /// Recorded with the acknowledgment so later wording changes can be distinguished.
    static let acknowledgmentVersion = "registration-ack-v1"

    let firstName: String
    let lastName: String
    let email: String
    let password: String
    let requestedChapterID: UUID?
    let acceptedAcknowledgment: Bool
}

enum SignUpResult: Equatable, Sendable {
    /// The account exists but the email address must be confirmed before signing in.
    case confirmationRequired(email: String)
    case signedIn(AuthUser)
}

enum AuthSessionChange: Sendable {
    case signedOut
    case sessionRefreshed
}

extension AuthService {
    func openPasswordRecovery(url: URL) async throws {
        throw AppError.configuration("Password recovery is unavailable in this environment.")
    }

    func updatePassword(_ password: String) async throws {
        throw AppError.configuration("Password recovery is unavailable in this environment.")
    }

    func closePasswordRecovery() async throws {
        try await signOut()
    }

    func completeEmailConfirmation(url: URL) async throws -> AuthUser {
        throw AppError.configuration("Email confirmation is unavailable in this environment.")
    }

    func deleteAccount() async throws {
        throw AppError.configuration("Account deletion is unavailable in this environment.")
    }

    func authStateChanges() async -> AsyncStream<AuthSessionChange> {
        AsyncStream { $0.finish() }
    }
}

enum PasswordRecoveryLink {
    static let redirectURL = URL(string: "org.rocksinc.rocks://recovery")!

    static func matches(_ url: URL) -> Bool {
        url.scheme?.lowercased() == redirectURL.scheme
            && url.host?.lowercased() == redirectURL.host
            && (url.path.isEmpty || url.path == "/")
            && url.user == nil && url.password == nil && url.port == nil
    }
}

/// Email-confirmation redirect. Must be allow-listed in Supabase Auth URL configuration.
enum AuthCallbackLink {
    static let redirectURL = URL(string: "org.rocksinc.rocks://auth-callback")!

    static func matches(_ url: URL) -> Bool {
        url.scheme?.lowercased() == redirectURL.scheme
            && url.host?.lowercased() == redirectURL.host
            && (url.path.isEmpty || url.path == "/")
            && url.user == nil && url.password == nil && url.port == nil
    }
}

protocol DemoSessionStore: Sendable {
    func containsSession() async throws -> Bool
    func saveSession() async throws
    func clearSession() async throws
}

actor KeychainDemoSessionStore: DemoSessionStore {
    private let service: String
    private let account = "active-demo-session"

    init(service: String = "org.rocksinc.ROCKS.demo-session") {
        self.service = service
    }

    func containsSession() async throws -> Bool {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query(returnData: true) as CFDictionary, &result)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else {
            throw keychainError("read", status: status)
        }
        return result as? Data != nil
    }

    func saveSession() async throws {
        let item = query()
        let data = Data([1])
        let updateStatus = SecItemUpdate(
            item as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw keychainError("save", status: updateStatus)
        }

        var newItem = item
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw keychainError("save", status: addStatus)
        }
    }

    func clearSession() async throws {
        let status = SecItemDelete(query() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError("clear", status: status)
        }
    }

    private func query(returnData: Bool = false) -> [String: Any] {
        var item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if returnData {
            item[kSecReturnData as String] = true
            item[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return item
    }

    private func keychainError(_ action: String, status: OSStatus) -> AppError {
        .configuration("Unable to \(action) the local demo session (Keychain status \(status)).")
    }
}

actor DemoAuthService: AuthService {
    #if DEMO_MODE_ENABLED
    static let credentialsHint: String? = "Demo access: demo@rocks.org / rocks1234"
    #else
    static let credentialsHint: String? = nil
    #endif

    static var isCompiledIn: Bool {
        #if DEMO_MODE_ENABLED
        true
        #else
        false
        #endif
    }

    static let demoUser = AuthUser(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000099")!,
        email: "demo@rocks.org",
        role: .member,
        authenticationProvider: .localDemo
    )

    private let enabled: Bool
    private let sessionStore: any DemoSessionStore

    init(
        enabled: Bool = DemoAuthService.isCompiledIn,
        sessionStore: any DemoSessionStore = KeychainDemoSessionStore()
    ) {
        self.enabled = enabled && Self.isCompiledIn
        self.sessionStore = sessionStore
    }

    func matches(email: String, password: String) -> Bool {
        guard enabled else { return false }
        #if DEMO_MODE_ENABLED
        return isDemoEmail(email)
            && password == "rocks1234"
        #else
        return false
        #endif
    }

    func isDemoEmail(_ email: String) -> Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == Self.demoUser.email
    }

    func currentUser() async throws -> AuthUser? {
        guard enabled else {
            try await sessionStore.clearSession()
            return nil
        }
        return try await sessionStore.containsSession() ? Self.demoUser : nil
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        guard matches(email: email, password: password) else {
            throw AppError.unauthenticated
        }
        try await sessionStore.saveSession()
        return Self.demoUser
    }

    func signUp(_ registration: RegistrationRequest) async throws -> SignUpResult {
        throw AppError.configuration("Demo accounts cannot create or modify real accounts.")
    }

    func deleteAccount() async throws {
        throw AppError.configuration("The local demo account cannot be deleted. Sign out instead.")
    }

    func requestPasswordReset(email: String) async throws {
        throw AppError.configuration("Password recovery is not available for the local demo account.")
    }

    func signOut() async throws {
        try await sessionStore.clearSession()
    }
}

actor AuthenticationRouter: AuthService {
    private let demo: DemoAuthService
    private let backend: any AuthService

    init(demo: DemoAuthService, backend: any AuthService) {
        self.demo = demo
        self.backend = backend
    }

    func currentUser() async throws -> AuthUser? {
        if let demoUser = try await demo.currentUser() {
            return demoUser
        }
        return try await backend.currentUser()
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        if await demo.matches(email: email, password: password) {
            return try await demo.signIn(email: email, password: password)
        }
        if await demo.isDemoEmail(email) {
            throw AppError.unauthenticated
        }
        return try await backend.signIn(email: email, password: password)
    }

    func signUp(_ registration: RegistrationRequest) async throws -> SignUpResult {
        if await demo.isDemoEmail(registration.email) {
            throw AppError.validation("That email address is reserved for the local demo.")
        }
        return try await backend.signUp(registration)
    }

    func completeEmailConfirmation(url: URL) async throws -> AuthUser {
        try await backend.completeEmailConfirmation(url: url)
    }

    func deleteAccount() async throws {
        if try await demo.currentUser() != nil {
            try await demo.deleteAccount()
            return
        }
        try await backend.deleteAccount()
    }

    func requestPasswordReset(email: String) async throws {
        try await backend.requestPasswordReset(email: email)
    }

    func openPasswordRecovery(url: URL) async throws {
        try await backend.openPasswordRecovery(url: url)
    }

    func updatePassword(_ password: String) async throws {
        try await backend.updatePassword(password)
    }

    func closePasswordRecovery() async throws {
        try await backend.closePasswordRecovery()
    }

    func signOut() async throws {
        if try await demo.currentUser() != nil {
            try await demo.signOut()
            return
        }
        try await backend.signOut()
    }

    func authStateChanges() async -> AsyncStream<AuthSessionChange> {
        await backend.authStateChanges()
    }
}

actor UnavailableAuthService: AuthService {
    func currentUser() async throws -> AuthUser? {
        nil
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        throw AppError.configuration("Sign-in is unavailable until Supabase is configured.")
    }

    func signUp(_ registration: RegistrationRequest) async throws -> SignUpResult {
        throw AppError.configuration("Account creation is unavailable until Supabase is configured.")
    }

    func requestPasswordReset(email: String) async throws {
        throw AppError.configuration("Password recovery is unavailable until Supabase is configured.")
    }

    func signOut() async throws {}
}
