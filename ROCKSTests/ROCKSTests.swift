import XCTest
import SwiftUI
import UIKit
@testable import ROCKS

final class ROCKSTests: XCTestCase {
    func testSemanticTextColorsMeetContrastInLightAndDarkAppearances() {
        let roles: [(String, Color, Color, CGFloat)] = [
            ("primary text", ROCKSColor.primaryText, ROCKSColor.background, 4.5),
            ("secondary text", ROCKSColor.subtleText, ROCKSColor.cardBackground, 4.5),
            ("accent text", ROCKSColor.goldText, ROCKSColor.cardBackground, 4.5),
            ("text on dark surface", ROCKSColor.onDarkText, ROCKSColor.charcoal, 4.5)
        ]

        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for (name, foreground, background, minimumRatio) in roles {
                let ratio = contrastRatio(
                    UIColor(foreground).resolvedColor(with: traits),
                    UIColor(background).resolvedColor(with: traits)
                )
                XCTAssertGreaterThanOrEqual(ratio, minimumRatio, "\(name) contrast in \(style) appearance")
            }
        }
    }

    func testChapterSearchMatchesNameAndLocation() {
        let chapters = Chapter.examples

        let cavazosMatches = chapters.filter { $0.matches(searchText: "Cavazos") }
        XCTAssertEqual(cavazosMatches.count, 1)
        XCTAssertEqual(cavazosMatches.first?.name, "Phantom Warriors ROCKS")

        let dcMatches = chapters.filter { $0.matches(searchText: "Washington") }
        XCTAssertEqual(dcMatches.first?.state, "DC")

        XCTAssertTrue(chapters.allSatisfy { $0.matches(searchText: "") })
    }

    func testChapterDirectoryHasNoFabricatedContactDetails() {
        for chapter in Chapter.examples {
            XCTAssertNil(chapter.contactPerson, "\(chapter.name) must not ship with unverified contact info")
            XCTAssertNil(chapter.email, "\(chapter.name) must not ship with unverified contact info")
        }
    }

    func testEventExamplesAreUpcoming() {
        XCTAssertTrue(ROCKSEvent.examples.allSatisfy { $0.startsAt > .now })
    }

    @MainActor
    func testAuthViewModelRejectsShortPassword() async {
        let viewModel = AuthViewModel(authService: UnavailableAuthService())
        viewModel.email = "member@example.com"
        viewModel.password = String(repeating: "x", count: 5)

        let user = await viewModel.signIn()

        XCTAssertNil(user)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testUnconfiguredAuthDoesNotSignIn() async {
        let viewModel = AuthViewModel(authService: UnavailableAuthService())
        viewModel.email = "member@example.com"
        viewModel.password = String(repeating: "x", count: 24)

        let user = await viewModel.signIn()

        XCTAssertNil(user)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testSessionRestoreWaitsForValidatedUserBeforeAuthenticating() async {
        let expectedUser = AuthUser(
            id: UUID(),
            email: "member@example.com",
            role: .member
        )
        let state = AppState(
            environment: .makeMock(),
            authenticationService: StubAuthService(result: .user(expectedUser)),
            isRestoringSession: true
        )

        XCTAssertTrue(state.isRestoringSession)
        XCTAssertFalse(state.isAuthenticated)

        await state.restoreSession()

        XCTAssertFalse(state.isRestoringSession)
        XCTAssertTrue(state.isAuthenticated)
        XCTAssertEqual(state.currentUser, expectedUser)
    }

    @MainActor
    func testSessionRestoreDoesNotAuthenticateWhenNoValidSessionExists() async {
        let state = AppState(
            environment: .makeMock(),
            authenticationService: StubAuthService(result: .noSession),
            isRestoringSession: true
        )

        await state.restoreSession()

        XCTAssertFalse(state.isRestoringSession)
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNil(state.currentUser)
    }

    @MainActor
    func testSessionRestoreSurfacesRefreshOrNetworkFailureWithoutAuthenticating() async {
        let state = AppState(
            environment: .makeMock(),
            authenticationService: StubAuthService(result: .networkFailure),
            isRestoringSession: true
        )

        await state.restoreSession()

        XCTAssertFalse(state.isRestoringSession)
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNotNil(state.authenticationError)
    }

    func testSupabaseClientEmitsLocalSessionAsInitialEvent() {
        XCTAssertTrue(SupabaseClientProvider.options.auth.emitLocalSessionAsInitialSession)
    }

    @MainActor
    func testRegistrationRejectsMissingNamesAndMismatchedPasswords() async {
        let viewModel = AuthViewModel(authService: UnavailableAuthService())
        viewModel.email = "member@example.com"
        viewModel.password = "long-password"
        viewModel.confirmPassword = "long-password"
        let missingNameResult = await viewModel.signUp()
        XCTAssertNil(missingNameResult)
        XCTAssertEqual(viewModel.errorMessage, "Enter your first and last name.")

        viewModel.firstName = "Test"
        viewModel.lastName = "Member"
        viewModel.confirmPassword = "different-password"
        let mismatchedResult = await viewModel.signUp()
        XCTAssertNil(mismatchedResult)
        XCTAssertEqual(viewModel.errorMessage, "Passwords do not match.")
    }

    @MainActor
    func testRecoveryRequestValidatesEmailBeforeContactingService() async {
        let viewModel = AuthViewModel(authService: UnavailableAuthService())
        viewModel.email = "invalid address"
        let success = await viewModel.requestPasswordReset()
        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.errorMessage, "Enter a valid email address.")
    }

    @MainActor
    func testRegistrationRequiresAcknowledgmentAndSendsApplicantDetails() async {
        let service = RegistrationCaptureService()
        let viewModel = AuthViewModel(authService: service)
        viewModel.firstName = " Test "
        viewModel.lastName = "Applicant"
        viewModel.email = "applicant@example.com"
        viewModel.password = "long-password"
        viewModel.confirmPassword = "long-password"
        let chapter = UUID()
        viewModel.requestedChapterID = chapter

        let withoutAcknowledgment = await viewModel.signUp()
        XCTAssertNil(withoutAcknowledgment)
        XCTAssertEqual(viewModel.errorMessage, "Review and accept the acknowledgment to continue.")
        let callsBefore = await service.requests.count
        XCTAssertEqual(callsBefore, 0, "Validation must happen before contacting the service")

        viewModel.acceptedAcknowledgment = true
        let result = await viewModel.signUp()
        XCTAssertEqual(result, .confirmationRequired(email: "applicant@example.com"))
        let sent = await service.requests.first
        XCTAssertEqual(sent?.firstName, "Test")
        XCTAssertEqual(sent?.requestedChapterID, chapter)
        XCTAssertEqual(sent?.acceptedAcknowledgment, true)
    }

    func testLiveRegistrationRejectsMissingAcknowledgmentBeforeNetwork() async throws {
        let configuration = AppConfiguration(
            supabaseURL: URL(string: "https://example.invalid"),
            supabaseAnonKey: "test-public-key",
            donationURL: nil,
            membershipPaymentURL: nil,
            champURL: OfficialLinks.mentorship,
            demoModeEnabled: false
        )
        let client = try XCTUnwrap(SupabaseClientProvider.makeClient(configuration: configuration))
        let service = SupabaseAuthService(client: client)
        let request = RegistrationRequest(
            firstName: "Test", lastName: "Member", email: "member@example.com",
            password: "example-password", requestedChapterID: nil, acceptedAcknowledgment: false
        )
        do {
            _ = try await service.signUp(request)
            XCTFail("Registration without acknowledgment must not reach the backend.")
        } catch let error as AppError {
            XCTAssertEqual(error.localizedDescription, "Review and accept the acknowledgment to continue.")
        }
    }

    func testRegistrationErrorsDoNotRevealExistingAccountsOrRawServerText() {
        let exists = SupabaseAuthService.registrationError(.api(message: "User already registered", errorCode: .userAlreadyExists, underlyingData: Data(), underlyingResponse: HTTPURLResponse()))
        XCTAssertFalse(exists.localizedDescription.contains("User already registered"))
        let disabled = SupabaseAuthService.registrationError(.api(message: "Signups not allowed", errorCode: .signupDisabled, underlyingData: Data(), underlyingResponse: HTTPURLResponse()))
        XCTAssertEqual(disabled.localizedDescription, "Account registration is currently closed.")
    }

    func testOnlyApprovedNonGuestAccountsHaveMemberAccess() {
        XCTAssertTrue(AuthUser(id: UUID(), email: "a@example.com", role: .member).hasMemberAccess)
        XCTAssertFalse(AuthUser(id: UUID(), email: "a@example.com", role: .guest, membershipStatus: .pending).hasMemberAccess)
        XCTAssertFalse(AuthUser(id: UUID(), email: "a@example.com", role: .member, membershipStatus: .suspended).hasMemberAccess)
        XCTAssertFalse(AuthUser(id: UUID(), email: "a@example.com", role: .guest, membershipStatus: .approved).hasMemberAccess)
    }

    @MainActor
    func testPendingApplicantIsAuthenticatedButWithoutMemberAccess() async {
        let applicant = AuthUser(id: UUID(), email: "applicant@example.com", role: .guest, membershipStatus: .pending)
        let state = AppState(environment: .makeMock(), authenticationService: StubAuthService(result: .user(applicant)), isRestoringSession: true)
        await state.restoreSession()
        XCTAssertTrue(state.isAuthenticated)
        XCTAssertEqual(state.currentUser?.hasMemberAccess, false)
    }

    func testEmailConfirmationLinkRejectsOtherDestinations() {
        XCTAssertTrue(AuthCallbackLink.matches(URL(string: "org.rocksinc.rocks://auth-callback?code=example")!))
        XCTAssertFalse(AuthCallbackLink.matches(URL(string: "org.rocksinc.rocks://recovery?code=example")!))
        XCTAssertFalse(AuthCallbackLink.matches(URL(string: "org.rocksinc.rocks://auth-callback/other")!))
        XCTAssertFalse(PasswordRecoveryLink.matches(URL(string: "org.rocksinc.rocks://auth-callback?code=example")!))
    }

    func testAttributionChapterLookupDecodesIdAndNameOnly() throws {
        // `chapterNames()` selects only id and name; decoding into ChapterRow failed in live mode.
        let data = Data(#"[{"id":"30000000-0000-0000-0000-000000000001","name":"Alamo ROCKS"}]"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode([ChapterRow].self, from: data))
        let rows = try JSONDecoder().decode([ChapterNameRow].self, from: data)
        XCTAssertEqual(rows.first?.name, "Alamo ROCKS")
    }

    func testProfileUpdateValidation() throws {
        XCTAssertThrowsError(try ProfileUpdate(firstName: " ", lastName: "Member", rankTitle: "", bio: "").validated())
        XCTAssertThrowsError(try ProfileUpdate(firstName: "A", lastName: "B", rankTitle: "", bio: String(repeating: "x", count: 1001)).validated())
        let valid = try ProfileUpdate(firstName: " Ada ", lastName: "Lee", rankTitle: " MAJ ", bio: "").validated()
        XCTAssertEqual(valid, ProfileUpdate(firstName: "Ada", lastName: "Lee", rankTitle: "MAJ", bio: ""))
    }

    func testRecoveryLinkRejectsOtherDestinations() {
        XCTAssertTrue(PasswordRecoveryLink.matches(URL(string: "org.rocksinc.rocks://recovery?code=example")!))
        XCTAssertFalse(PasswordRecoveryLink.matches(URL(string: "org.rocksinc.rocks://recovery.evil.example?code=example")!))
        XCTAssertFalse(PasswordRecoveryLink.matches(URL(string: "https://recovery?code=example")!))
        XCTAssertFalse(PasswordRecoveryLink.matches(URL(string: "org.rocksinc.rocks://recovery/other?code=example")!))
    }

    @MainActor
    func testRecoverySessionMustBeClosedBeforeReturningToSignIn() async {
        defer { UserDefaults.standard.removeObject(forKey: "authPasswordRecoveryInProgress") }
        let service = RecoveryAuthService()
        let state = AppState(environment: .makeMock(), authenticationService: service)
        await state.openPasswordRecovery(URL(string: "org.rocksinc.rocks://recovery?code=example")!)
        XCTAssertEqual(state.passwordRecoveryState, .ready)
        XCTAssertFalse(state.isAuthenticated)
        await state.updateRecoveredPassword("new-password")
        XCTAssertEqual(state.passwordRecoveryState, .updated)
        await state.closePasswordRecovery()
        XCTAssertNil(state.passwordRecoveryState)
        let closed = await service.closeCount
        XCTAssertEqual(closed, 1)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "authPasswordRecoveryInProgress"))
    }

    @MainActor
    func testInterruptedRecoveryIsNotRestoredAsAnAuthenticatedSession() async {
        defer { UserDefaults.standard.removeObject(forKey: "authPasswordRecoveryInProgress") }
        UserDefaults.standard.set(true, forKey: "authPasswordRecoveryInProgress")
        let service = RecoveryAuthService()
        let state = AppState(environment: .makeMock(), authenticationService: service, isRestoringSession: true)
        await state.restoreSession()
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNotNil(state.authenticationError)
        let closed = await service.closeCount
        XCTAssertEqual(closed, 1)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "authPasswordRecoveryInProgress"))
    }

    @MainActor
    func testRecoverySignOutFailureKeepsTheRecoveryGate() async {
        defer { UserDefaults.standard.removeObject(forKey: "authPasswordRecoveryInProgress") }
        let service = RecoveryAuthService(failClose: true)
        let state = AppState(environment: .makeMock(), authenticationService: service)
        await state.openPasswordRecovery(URL(string: "org.rocksinc.rocks://recovery?code=example")!)
        await state.closePasswordRecovery()
        XCTAssertEqual(state.passwordRecoveryState, .ready)
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertNotNil(state.passwordRecoveryError)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "authPasswordRecoveryInProgress"))
    }

    private func contrastRatio(_ foreground: UIColor, _ background: UIColor) -> CGFloat {
        func luminance(_ color: UIColor) -> CGFloat {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: nil)

            func linearize(_ component: CGFloat) -> CGFloat {
                component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
            }

            return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
        }

        let first = luminance(foreground)
        let second = luminance(background)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
}

private actor RecoveryAuthService: AuthService {
    private(set) var closeCount = 0
    private let failClose: Bool

    init(failClose: Bool = false) {
        self.failClose = failClose
    }

    func currentUser() async throws -> AuthUser? {
        AuthUser(id: UUID(), email: "member@example.com", role: .member)
    }
    func signIn(email: String, password: String) async throws -> AuthUser { throw AppError.unauthenticated }
    func signUp(_ registration: RegistrationRequest) async throws -> SignUpResult { throw AppError.unauthenticated }
    func requestPasswordReset(email: String) async throws {}
    func openPasswordRecovery(url: URL) async throws {}
    func updatePassword(_ password: String) async throws {}
    func closePasswordRecovery() async throws {
        closeCount += 1
        if failClose { throw AppError.configuration("Could not close recovery.") }
    }
    func signOut() async throws {}
}

private actor StubAuthService: AuthService {
    enum ResultState: Sendable {
        case user(AuthUser)
        case noSession
        case networkFailure
    }

    private let result: ResultState

    init(result: ResultState) {
        self.result = result
    }

    func currentUser() async throws -> AuthUser? {
        switch result {
        case .user(let user):
            user
        case .noSession:
            nil
        case .networkFailure:
            throw URLError(.notConnectedToInternet)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        throw AppError.unauthenticated
    }

    func signUp(_ registration: RegistrationRequest) async throws -> SignUpResult {
        throw AppError.unauthenticated
    }

    func requestPasswordReset(email: String) async throws {
        throw AppError.unauthenticated
    }

    func signOut() async throws {}
}

private actor RegistrationCaptureService: AuthService {
    private(set) var requests: [RegistrationRequest] = []

    func currentUser() async throws -> AuthUser? { nil }
    func signIn(email: String, password: String) async throws -> AuthUser { throw AppError.unauthenticated }
    func signUp(_ registration: RegistrationRequest) async throws -> SignUpResult {
        requests.append(registration)
        return .confirmationRequired(email: registration.email)
    }
    func requestPasswordReset(email: String) async throws {}
    func signOut() async throws {}
}
