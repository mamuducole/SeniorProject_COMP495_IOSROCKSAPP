import Foundation
import Supabase

struct AppEnvironment {
    let configuration: AppConfiguration
    let authService: any AuthService
    let chapterRepository: any ChapterRepository
    let adminRepository: any AdminRepository
    let eventRepository: any EventRepository
    let eventRegistrationService: any EventRegistrationService
    let newsRepository: any NewsRepository
    let memberRepository: any MemberRepository
    let feedRepository: any FeedRepository
    let mentorshipRepository: any MentorshipRepository
    let scholarshipRepository: any ScholarshipRepository
    let notificationRepository: any NotificationRepository

    let isDemoEnvironment: Bool

    var isLive: Bool { configuration.isSupabaseConfigured && !isDemoEnvironment }

    static var preview: AppEnvironment { makeMock() }

    static func makeMock(configuration: AppConfiguration = .preview) -> AppEnvironment {
        AppEnvironment(
            configuration: configuration,
            authService: UnavailableAuthService(),
            chapterRepository: MockChapterRepository(),
            adminRepository: UnavailableRepositories(),
            eventRepository: MockEventRepository(),
            eventRegistrationService: MockEventRegistrationService(),
            newsRepository: MockNewsRepository(),
            memberRepository: MockMemberRepository(),
            feedRepository: MockFeedRepository(),
            mentorshipRepository: MockMentorshipRepository(),
            scholarshipRepository: MockScholarshipRepository(),
            notificationRepository: MockNotificationRepository(),
            isDemoEnvironment: false
        )
    }

    static func makeDemo(configuration: AppConfiguration = .preview) -> AppEnvironment {
        AppEnvironment(
            configuration: configuration,
            authService: AuthenticationRouter(
                demo: DemoAuthService(enabled: configuration.demoModeEnabled),
                backend: UnavailableAuthService()
            ),
            chapterRepository: MockChapterRepository(),
            adminRepository: UnavailableRepositories(),
            eventRepository: MockEventRepository(),
            eventRegistrationService: MockEventRegistrationService(),
            newsRepository: MockNewsRepository(),
            memberRepository: MockMemberRepository(),
            feedRepository: MockFeedRepository(),
            mentorshipRepository: MockMentorshipRepository(),
            scholarshipRepository: MockScholarshipRepository(),
            notificationRepository: MockNotificationRepository(),
            isDemoEnvironment: true
        )
    }

    static func makeLive(configuration: AppConfiguration = .load()) throws -> AppEnvironment {
        guard configuration.isSupabaseConfigured,
              let client = SupabaseClientProvider.makeClient(configuration: configuration) else {
            throw AppError.configuration("Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to the app configuration.")
        }

        return AppEnvironment(
            configuration: configuration,
            authService: AuthenticationRouter(
                demo: DemoAuthService(enabled: configuration.demoModeEnabled),
                backend: SupabaseAuthService(client: client)
            ),
            chapterRepository: SupabaseChapterRepository(client: client, configuration: configuration),
            adminRepository: SupabaseAdminRepository(client: client, configuration: configuration),
            eventRepository: SupabaseEventRepository(client: client, configuration: configuration),
            eventRegistrationService: SupabaseEventRegistrationService(client: client),
            newsRepository: SupabaseNewsRepository(client: client),
            memberRepository: SupabaseMemberRepository(client: client, configuration: configuration),
            feedRepository: SupabaseFeedRepository(client: client, configuration: configuration),
            mentorshipRepository: SupabaseMentorshipRepository(client: client, configuration: configuration),
            scholarshipRepository: SupabaseScholarshipRepository(client: client, configuration: configuration),
            notificationRepository: SupabaseNotificationRepository(client: client, configuration: configuration),
            isDemoEnvironment: false
        )
    }

    static func makeUnavailable(configuration: AppConfiguration = .load()) -> AppEnvironment {
        let repositories = UnavailableRepositories()
        return AppEnvironment(
            configuration: configuration,
            authService: AuthenticationRouter(
                demo: DemoAuthService(enabled: configuration.demoModeEnabled),
                backend: UnavailableAuthService()
            ),
            chapterRepository: repositories,
            adminRepository: repositories,
            eventRepository: repositories,
            eventRegistrationService: repositories,
            newsRepository: repositories,
            memberRepository: repositories,
            feedRepository: repositories,
            mentorshipRepository: repositories,
            scholarshipRepository: repositories,
            notificationRepository: repositories,
            isDemoEnvironment: false
        )
    }
}

struct AppConfiguration: Sendable {
    let supabaseURL: URL?
    let supabaseAnonKey: String?
    let donationURL: URL?
    let membershipPaymentURL: URL?
    let champURL: URL
    let demoModeEnabled: Bool
    var termsURL: URL?
    var privacyPolicyURL: URL?

    private static var buildAllowsDemo: Bool {
        #if DEMO_MODE_ENABLED
        true
        #else
        false
        #endif
    }

    var isSupabaseConfigured: Bool {
        supabaseURL != nil && !(supabaseAnonKey?.isEmpty ?? true)
    }

    static let preview = AppConfiguration(
        supabaseURL: nil,
        supabaseAnonKey: nil,
        donationURL: OfficialLinks.donate,
        membershipPaymentURL: nil,
        champURL: OfficialLinks.mentorship,
        demoModeEnabled: buildAllowsDemo
    )

    static func load(bundle: Bundle = .main) -> AppConfiguration {
        let info = bundle.infoDictionary ?? [:]
        return AppConfiguration(
            supabaseURL: validURL(info["SUPABASE_URL"] as? String),
            supabaseAnonKey: nonEmpty(info["SUPABASE_ANON_KEY"] as? String),
            donationURL: validURL(info["DONATION_URL"] as? String),
            membershipPaymentURL: validURL(info["MEMBERSHIP_PAYMENT_URL"] as? String),
            champURL: validURL(info["CHAMP_URL"] as? String) ?? OfficialLinks.mentorship,
            demoModeEnabled: buildAllowsDemo && boolean(info["DEMO_MODE_ENABLED"]),
            termsURL: validURL(info["TERMS_URL"] as? String),
            privacyPolicyURL: validURL(info["PRIVACY_POLICY_URL"] as? String)
        )
    }

    private static func boolean(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        guard let value = value as? String else { return false }
        return ["yes", "true", "1"].contains(value.lowercased())
    }

    private static func validURL(_ value: String?) -> URL? {
        guard let value = nonEmpty(value),
              let url = URL(string: value),
              url.scheme == "https",
              url.host != nil else { return nil }
        return url
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !value.hasPrefix("replace-with-"),
              !value.contains("your-project") else { return nil }
        return value
    }

    func publicAssetURL(path: String?) -> URL? {
        guard let path, !path.isEmpty, let baseURL = supabaseURL else { return nil }
        return baseURL
            .appending(path: "storage/v1/object/public/rocks-public/\(path)")
    }
}

private struct UnavailableRepositories:
    ChapterRepository,
    AdminRepository,
    EventRepository,
    EventRegistrationService,
    NewsRepository,
    MemberRepository,
    FeedRepository,
    MentorshipRepository,
    ScholarshipRepository,
    NotificationRepository
{
    private func unavailable<T>() throws -> T {
        throw AppError.configuration("This feature is unavailable until Supabase is configured.")
    }

    func fetchChapters() async throws -> [Chapter] { try unavailable() }
    func fetchChapter(id: UUID) async throws -> Chapter? { try unavailable() }
    func fetchManagedChapters() async throws -> [Chapter] { try unavailable() }
    func updateChapter(id: UUID, description: String, email: String, website: String) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func fetchActivity() async throws -> [AdministrativeActivity] { try unavailable() }
    func fetchMembershipApplications(status: MembershipStatus) async throws -> [MembershipApplication] { try unavailable() }
    func reviewMembership(profileID: UUID, decision: MembershipDecision) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func fetchOpenReports() async throws -> [ContentReport] { try unavailable() }
    func resolveReport(id: UUID, dismissed: Bool) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func removeReportedContent(_ report: ContentReport) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func fetchUpcomingEvents() async throws -> [ROCKSEvent] { try unavailable() }
    func fetchMyEvents() async throws -> [ROCKSEvent] { try unavailable() }
    func fetchPastEvents() async throws -> [ROCKSEvent] { try unavailable() }
    func fetchEvent(id: UUID) async throws -> ROCKSEvent? { try unavailable() }
    func register(for event: ROCKSEvent) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func cancel(for event: ROCKSEvent) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func fetchLatestNews() async throws -> [NewsArticle] { try unavailable() }
    func fetchArticle(id: UUID) async throws -> NewsArticle? { try unavailable() }
    func fetchMembers() async throws -> [MemberProfile] { try unavailable() }
    func fetchProfile(id: UUID) async throws -> MemberProfile? { try unavailable() }
    func updateOwnProfile(_ update: ProfileUpdate) async throws -> MemberProfile { try unavailable() }
    func fetchPosts() async throws -> [Post] { try unavailable() }
    func fetchPost(id: UUID) async throws -> Post? { try unavailable() }
    func createPost(body: String, imageName: String?) async throws -> Post { try unavailable() }
    func updatePost(id: UUID, body: String) async throws -> Post { try unavailable() }
    func deletePost(id: UUID) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func setLiked(postID: UUID, liked: Bool) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func addComment(postID: UUID, body: String) async throws -> PostComment { try unavailable() }
    func deleteComment(id: UUID, postID: UUID) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func report(_ target: ReportTarget, reason: ReportReason) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func fetchMentors() async throws -> [MentorProfile] { try unavailable() }
    func fetchMentor(id: UUID) async throws -> MentorProfile? { try unavailable() }
    func fetchRequests() async throws -> [MentorshipRequest] { try unavailable() }
    func fetchConnections() async throws -> [MentorshipConnection] { try unavailable() }
    func sendRequest(mentorID: UUID, message: String) async throws -> MentorshipRequest { try unavailable() }
    func respondToRequest(id: UUID, accept: Bool) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func cancelRequest(id: UUID) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func endConnection(id: UUID) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func becomeMentor(settings: MentorDirectorySettings) async throws -> MentorProfile { try unavailable() }
    func hideMentorProfile() async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func addGoal(connectionID: UUID, title: String, milestones: [String]) async throws -> MentorshipGoal { try unavailable() }
    func setGoalProgress(connectionID: UUID, goalID: UUID, percent: Int) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func setGoalComplete(connectionID: UUID, goalID: UUID, complete: Bool) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func addCheckIn(connectionID: UUID, note: String, meetingAt: Date, nextSteps: String?) async throws -> MentorshipCheckIn { try unavailable() }
    func fetchActiveScholarships() async throws -> [Scholarship] { try unavailable() }
    func fetchNotifications() async throws -> [AppNotification] { try unavailable() }
    func markAllRead() async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
    func markRead(id: UUID) async throws { throw AppError.configuration("This feature is unavailable until Supabase is configured.") }
}
