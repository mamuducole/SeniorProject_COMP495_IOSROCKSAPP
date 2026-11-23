import Foundation
import Observation

enum AppTab: Hashable {
    case home
    case connect
    case events
    case learn
    case you
}

enum PasswordRecoveryState: Equatable {
    case opening
    case ready
    case updated
    case failed(String)
}

@Observable
@MainActor
final class AppState {
    private static let recoveryInProgressKey = "authPasswordRecoveryInProgress"
    var hasCompletedOnboarding: Bool
    var isAuthenticated = false
    var isRestoringSession: Bool
    var currentUser: AuthUser?
    var currentMember: MemberProfile?
    var authenticationError: String?
    var passwordRecoveryState: PasswordRecoveryState?
    var passwordRecoveryError: String?
    var pendingDeepLink: DeepLinkRoute?
    var selectedTab: AppTab = .home
    private let baseEnvironment: AppEnvironment
    private let authenticationService: any AuthService
    private var authStateTask: Task<Void, Never>?
    private var didRestoreSession = false
    private var pendingRecoveryURL: URL?
    private var pendingConfirmationURL: URL?
    var registrationNotice: String?
    var environment: AppEnvironment
    var authService: any AuthService { authenticationService }
    var isDemoUser: Bool { currentUser?.isDemo == true }

    init(
        environment: AppEnvironment,
        authenticationService: (any AuthService)? = nil,
        isRestoringSession: Bool = false
    ) {
        self.baseEnvironment = environment
        self.authenticationService = authenticationService ?? environment.authService
        self.environment = environment
        self.isRestoringSession = isRestoringSession
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    static var preview: AppState {
        AppState(environment: .makeDemo())
    }

    static func production() -> AppState {
        let configuration = AppConfiguration.load()
        do {
            return AppState(
                environment: try .makeLive(configuration: configuration),
                isRestoringSession: true
            )
        } catch {
            return AppState(
                environment: .makeUnavailable(configuration: configuration),
                isRestoringSession: true
            )
        }
    }

    func restoreSession() async {
        guard !didRestoreSession else { return }
        didRestoreSession = true
        isRestoringSession = true
        await observeAuthStateChanges()
        defer {
            isRestoringSession = false
            if let url = pendingRecoveryURL {
                pendingRecoveryURL = nil
                Task { await openPasswordRecovery(url) }
            } else if let url = pendingConfirmationURL {
                pendingConfirmationURL = nil
                Task { await completeEmailConfirmation(url) }
            }
        }

        do {
            if UserDefaults.standard.bool(forKey: Self.recoveryInProgressKey) {
                try await authService.closePasswordRecovery()
                UserDefaults.standard.removeObject(forKey: Self.recoveryInProgressKey)
                clearAuthenticatedState()
                authenticationError = "Password recovery was interrupted. Request a new link."
                return
            }
            guard let user = try await authService.currentUser() else {
                clearAuthenticatedState()
                return
            }
            authenticate(user)
        } catch {
            clearAuthenticatedState()
            let message = (error as? LocalizedError)?.errorDescription ?? "Unable to restore your session."
            if UserDefaults.standard.bool(forKey: Self.recoveryInProgressKey) {
                passwordRecoveryState = .failed(message)
            } else {
                authenticationError = message
            }
        }
    }

    func validateSession() async {
        guard isAuthenticated, !isDemoUser else { return }
        do {
            guard let user = try await authService.currentUser() else {
                clearAuthenticatedState()
                return
            }
            authenticate(user)
        } catch {
            clearAuthenticatedState()
            authenticationError = (error as? LocalizedError)?.errorDescription ?? "Unable to validate your session."
        }
    }

    private func observeAuthStateChanges() async {
        guard authStateTask == nil else { return }
        let changes = await authService.authStateChanges()
        authStateTask = Task { [weak self] in
            for await change in changes {
                guard let self else { return }
                switch change {
                case .signedOut:
                    clearAuthenticatedState()
                case .sessionRefreshed:
                    await validateSession()
                }
            }
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func authenticate(_ user: AuthUser) {
        authenticationError = nil
        currentUser = user
        isAuthenticated = true
        if user.isDemo {
            environment = .makeDemo(configuration: baseEnvironment.configuration)
            currentMember = .demo
            return
        }

        environment = baseEnvironment
        Task {
            currentMember = try? await environment.memberRepository.fetchProfile(id: user.id)
        }
    }

    func selectTab(for route: DeepLinkRoute) {
        switch route {
        case .event:
            selectedTab = .events
        case .chapter, .news, .scholarship, .mentor:
            selectedTab = .connect
        }
    }

    func openPasswordRecovery(_ url: URL) async {
        guard PasswordRecoveryLink.matches(url) else { return }
        if isRestoringSession {
            pendingRecoveryURL = url
            return
        }
        guard !isAuthenticated else {
            passwordRecoveryState = .failed("Sign out before opening a password recovery link.")
            return
        }
        passwordRecoveryState = .opening
        passwordRecoveryError = nil
        UserDefaults.standard.set(true, forKey: Self.recoveryInProgressKey)
        do {
            try await authService.openPasswordRecovery(url: url)
            clearAuthenticatedState()
            passwordRecoveryState = .ready
        } catch {
            passwordRecoveryState = .failed(
                (error as? LocalizedError)?.errorDescription ?? "Unable to open the recovery link."
            )
        }
    }

    func updateRecoveredPassword(_ password: String) async {
        guard passwordRecoveryState == .ready else { return }
        passwordRecoveryError = nil
        do {
            try await authService.updatePassword(password)
            passwordRecoveryState = .updated
        } catch {
            passwordRecoveryError = (error as? LocalizedError)?.errorDescription ?? "Unable to update your password."
        }
    }

    func closePasswordRecovery() async {
        guard let state = passwordRecoveryState else { return }
        if state == .ready || state == .updated || UserDefaults.standard.bool(forKey: Self.recoveryInProgressKey) {
            do {
                try await authService.closePasswordRecovery()
                UserDefaults.standard.removeObject(forKey: Self.recoveryInProgressKey)
                clearAuthenticatedState()
            } catch {
                passwordRecoveryError = (error as? LocalizedError)?.errorDescription ?? "Unable to sign out of recovery."
                return
            }
        }
        passwordRecoveryError = nil
        passwordRecoveryState = nil
    }

    func completeEmailConfirmation(_ url: URL) async {
        guard AuthCallbackLink.matches(url) else { return }
        if isRestoringSession {
            pendingConfirmationURL = url
            return
        }
        guard !isAuthenticated else { return }
        do {
            let user = try await authService.completeEmailConfirmation(url: url)
            authenticate(user)
        } catch {
            authenticationError = (error as? LocalizedError)?.errorDescription ?? "Unable to confirm your email address."
        }
    }

    /// Returns an error message, or nil when the profile was saved.
    func updateProfile(_ update: ProfileUpdate) async -> String? {
        do {
            currentMember = try await environment.memberRepository.updateOwnProfile(update)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? "Unable to save your profile."
        }
    }

    /// Re-reads role and membership status, e.g. after an administrator approves the account.
    func refreshAccess() async {
        await validateSession()
    }

    /// Returns an error message, or nil when the account was deleted and the session cleared.
    func deleteAccount() async -> String? {
        do {
            try await authService.deleteAccount()
            clearAuthenticatedState()
            authenticationError = nil
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? "Your account could not be deleted."
        }
    }

    func signOut() async {
        do {
            try await authService.signOut()
            clearAuthenticatedState()
            authenticationError = nil
        } catch {
            if !isDemoUser {
                clearAuthenticatedState()
            }
            authenticationError = (error as? LocalizedError)?.errorDescription ?? "Unable to sign out right now."
        }
    }

    private func clearAuthenticatedState() {
        currentUser = nil
        currentMember = nil
        isAuthenticated = false
        environment = baseEnvironment
    }
}
