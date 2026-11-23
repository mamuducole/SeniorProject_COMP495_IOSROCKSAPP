import XCTest
import SwiftUI
@testable import ROCKS

@MainActor
final class FeatureViewModelTests: XCTestCase {
    private func makeEnvironment() -> AppEnvironment { .preview }

    func testDeepLinkTabSelectionUsesAvailableNavigation() {
        let state = AppState(environment: makeEnvironment())
        let id = UUID()
        state.selectTab(for: .event(id))
        XCTAssertEqual(state.selectedTab, .events)
        for route in [DeepLinkRoute.chapter(id), .news(id), .scholarship(id), .mentor(id)] {
            state.selectTab(for: route)
            XCTAssertEqual(state.selectedTab, .connect)
        }
    }

    func testDemoNavigationScreenshots() async throws {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw XCTSkip("No active simulator window scene is available for screenshots.")
        }
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let state = AppState(environment: .makeDemo())
        state.authenticate(AuthUser(id: MemberProfile.demo.id, email: "demo@rocks.org", role: .member, authenticationProvider: .localDemo))
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIHostingController(rootView: MainTabView().environment(state))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }

        for (style, appearance) in [(UIUserInterfaceStyle.light, "Light"), (.dark, "Dark")] {
            window.overrideUserInterfaceStyle = style
            for (tab, name) in [(AppTab.home, "Home"), (.connect, "Connect"), (.events, "Events"), (.learn, "Learn"), (.you, "You")] {
                state.selectedTab = tab
                try await Task.sleep(for: .milliseconds(700))
                window.rootViewController?.view.layoutIfNeeded()
                var rendered = false
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                XCTAssertTrue(rendered, "Unable to render \(name) in the simulator")
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(name) - demo - \(appearance)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testHomeViewModelAggregatesDashboardStats() async {
        let viewModel = HomeViewModel(environment: makeEnvironment())

        await viewModel.load()

        XCTAssertEqual(viewModel.upcomingEventCount, ROCKSEvent.examples.count)
        XCTAssertEqual(viewModel.unreadNotificationCount, AppNotification.examples.filter { !$0.isRead }.count)
        XCTAssertEqual(viewModel.mentorshipRequestCount, MentorshipRequest.examples.filter { $0.status == .pending }.count)
        XCTAssertEqual(viewModel.scholarshipDeadlineCount, Scholarship.examples.count)
        XCTAssertNotNil(viewModel.featuredEvent)
    }

    func testHomeGreetingIncludesMemberFirstName() {
        let viewModel = HomeViewModel(environment: makeEnvironment())
        let member = MemberProfile(id: UUID(), firstName: "Jordan", lastName: "Lee")

        XCTAssertTrue(viewModel.greeting(for: member).contains("Jordan"))
        XCTAssertTrue(viewModel.greeting(for: nil).contains("Member"))
    }

    func testAdminRepositoryRejectsAllCallsWithoutASignedInSession() async throws {
        let configuration = AppConfiguration(
            supabaseURL: URL(string: "https://example.test"),
            supabaseAnonKey: "test-anon-key",
            donationURL: nil,
            membershipPaymentURL: nil,
            champURL: OfficialLinks.mentorship,
            demoModeEnabled: false
        )
        let client = try XCTUnwrap(SupabaseClientProvider.makeClient(configuration: configuration))
        let repository = SupabaseAdminRepository(client: client, configuration: configuration)
        do {
            _ = try await repository.fetchManagedChapters()
            XCTFail("Administration requires a signed-in session")
        } catch AppError.unauthenticated {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        do {
            try await repository.updateChapter(id: UUID(), description: "", email: "", website: "")
            XCTFail("Chapter updates require a signed-in session")
        } catch AppError.unauthenticated {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        do {
            _ = try await repository.fetchActivity()
            XCTFail("Audit access requires a signed-in session")
        } catch AppError.unauthenticated {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEventsViewModelFiltersBySelectedTab() async {
        let viewModel = EventsViewModel(environment: makeEnvironment())

        await viewModel.load()

        viewModel.selectedTab = .upcoming
        XCTAssertEqual(viewModel.visibleEvents.count, ROCKSEvent.examples.count)
        XCTAssertTrue(viewModel.visibleEvents.allSatisfy { $0.isUpcoming })

        viewModel.selectedTab = .myEvents
        XCTAssertTrue(viewModel.visibleEvents.allSatisfy { $0.isRegisteredByCurrentUser })

        viewModel.selectedTab = .past
        XCTAssertEqual(viewModel.visibleEvents.count, ROCKSEvent.pastExamples.count)
        XCTAssertTrue(viewModel.visibleEvents.allSatisfy { !$0.isUpcoming })
    }

    func testFeedViewModelLikeIsOptimistic() async {
        let viewModel = FeedViewModel(environment: makeEnvironment())
        await viewModel.load()

        guard let post = viewModel.posts.first else {
            XCTFail("Expected mock posts")
            return
        }
        let originalLikes = post.likeCount
        let originalState = post.isLikedByCurrentUser

        await viewModel.toggleLike(for: post)

        let updated = viewModel.posts.first { $0.id == post.id }
        XCTAssertEqual(updated?.isLikedByCurrentUser, !originalState)
        XCTAssertEqual(updated?.likeCount, originalLikes + (originalState ? -1 : 1))
    }

    func testFeedViewModelPublishesDraft() async {
        let viewModel = FeedViewModel(environment: makeEnvironment())
        await viewModel.load()
        let countBefore = viewModel.posts.count
        viewModel.draftBody = "Proud to serve alongside this community."

        let published = await viewModel.publishDraft()

        XCTAssertTrue(published)
        XCTAssertEqual(viewModel.posts.count, countBefore + 1)
        XCTAssertEqual(viewModel.posts.first?.body, "Proud to serve alongside this community.")
        XCTAssertTrue(viewModel.draftBody.isEmpty)
    }

    func testMentorshipViewModelSendsRequest() async {
        let viewModel = MentorshipViewModel(environment: makeEnvironment())
        await viewModel.load()
        let mentor = MentorProfile.examples[3]
        let countBefore = viewModel.pendingRequests.count

        let sent = await viewModel.sendRequest(to: mentor, message: "I'd value your guidance on command selection.")

        XCTAssertTrue(sent)
        XCTAssertEqual(viewModel.pendingRequests.count, countBefore + 1)
        XCTAssertEqual(viewModel.pendingRequests.first?.mentor.id, mentor.id)
    }

    func testMentorshipViewModelPreventsDuplicatePendingRequest() async {
        let viewModel = MentorshipViewModel(environment: makeEnvironment())
        await viewModel.load()
        let existing = MentorshipRequest.examples[0]

        let sent = await viewModel.sendRequest(to: existing.mentor, message: "Following up.")

        XCTAssertFalse(sent)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testMentorshipViewModelAddsGoalAndCheckIn() async {
        let viewModel = MentorshipViewModel(environment: makeEnvironment())
        await viewModel.load()
        let connection = MentorshipConnection.examples[0]
        let goalsBefore = connection.goals.count
        let checkInsBefore = connection.checkIns.count

        let goalAdded = await viewModel.addGoal("Mentor a JROTC cadet", to: connection)
        let checkInAdded = await viewModel.addCheckIn(note: "Monthly sync on scholarship progress.", meetingAt: .now, to: connection)

        XCTAssertTrue(goalAdded)
        XCTAssertTrue(checkInAdded)
        let updated = viewModel.connections.first { $0.id == connection.id }
        XCTAssertEqual(updated?.goals.count, goalsBefore + 1)
        XCTAssertEqual(updated?.checkIns.count, checkInsBefore + 1)
    }

    func testMentorSuggestionsExplainSharedInterestsAndExcludeUnavailableMentors() {
        let mentor = MentorProfile.examples[0]
        XCTAssertEqual(
            MentorshipViewModel.matchReasons(for: mentor, preferences: "Leadership, Logistics"),
            ["Leadership"]
        )
        XCTAssertTrue(MentorshipViewModel.matchReasons(
            for: MentorProfile.examples[2], preferences: "Scholarships"
        ).isEmpty)
    }

    func testMentorSearchCombinesInterestAndAvailabilityFilters() {
        var mentor = MentorProfile.examples[0]
        mentor.careerField = "Logistics"
        mentor.careerBackground = "Military"
        mentor.interests = ["Coaching"]
        XCTAssertTrue(MentorshipViewModel.matches(
            mentor, search: "coach", availableOnly: true,
            career: "Logistics", background: "Military", chapter: ""
        ))
        XCTAssertFalse(MentorshipViewModel.matches(
            mentor, search: "coach", availableOnly: true,
            career: "Medical", background: "Military", chapter: ""
        ))
        XCTAssertFalse(MentorshipViewModel.matches(
            MentorProfile.examples[2], search: "", availableOnly: true,
            career: "", background: "", chapter: ""
        ))
    }

    func testMentorshipCanCancelOutgoingRequestAndEndConnection() async {
        let viewModel = MentorshipViewModel(
            environment: makeEnvironment(), currentUserID: MemberProfile.demo.id
        )
        await viewModel.load()
        guard let request = viewModel.pendingRequests.first,
              let connection = viewModel.connections.first else {
            XCTFail("Expected demo mentorship data")
            return
        }

        await viewModel.cancel(request)
        let ended = await viewModel.end(connection)

        XCTAssertFalse(viewModel.requests.contains { $0.id == request.id })
        XCTAssertTrue(ended)
        XCTAssertFalse(viewModel.connections.contains { $0.id == connection.id })
    }

    func testMentorshipTracksGoalMilestonesAndProgressHistory() async {
        let viewModel = MentorshipViewModel(environment: makeEnvironment())
        await viewModel.load()
        guard let connection = viewModel.connections.first else {
            XCTFail("Expected demo mentorship data")
            return
        }
        let added = await viewModel.addGoal("Build a plan", milestones: ["Draft", "Review"], to: connection)
        XCTAssertTrue(added)
        guard let goal = viewModel.connections.first?.goals.last else {
            XCTFail("Expected new goal")
            return
        }
        await viewModel.updateProgress(goal, percent: 50, in: connection)
        let updated = viewModel.connections.first?.goals.first { $0.id == goal.id }
        XCTAssertEqual(updated?.milestones, ["Draft", "Review"])
        XCTAssertEqual(updated?.progressPercent, 50)
        XCTAssertEqual(updated?.history.map(\.percent), [0, 50])
        XCTAssertFalse(updated?.isComplete ?? true)
    }

    func testLiveMentorshipRequiresASignedInSession() async throws {
        let configuration = AppConfiguration(
            supabaseURL: URL(string: "https://example.test"),
            supabaseAnonKey: "test-anon-key",
            donationURL: nil,
            membershipPaymentURL: nil,
            champURL: OfficialLinks.mentorship,
            demoModeEnabled: false
        )
        let client = try XCTUnwrap(SupabaseClientProvider.makeClient(configuration: configuration))
        let repository = SupabaseMentorshipRepository(client: client, configuration: configuration)
        do {
            _ = try await repository.fetchMentors()
            XCTFail("Live mentorship requires a signed-in session")
        } catch AppError.unauthenticated {
            // Expected before any network request; the server enforces approved-member access.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNotificationsViewModelMarkAllReadClearsBadge() async {
        let viewModel = NotificationsViewModel(environment: makeEnvironment())
        await viewModel.load()
        XCTAssertGreaterThan(viewModel.unreadCount, 0)

        await viewModel.markAllRead()

        XCTAssertEqual(viewModel.unreadCount, 0)
    }

    func testScholarshipDeadlinesAreInTheFuture() {
        XCTAssertTrue(Scholarship.examples.allSatisfy { $0.daysRemaining > 0 })
    }

    func testFailedMarkAllReadRestoresUnreadState() async {
        let mock = AppEnvironment.preview
        let environment = AppEnvironment(
            configuration: mock.configuration, authService: mock.authService,
            chapterRepository: mock.chapterRepository, adminRepository: mock.adminRepository,
            eventRepository: mock.eventRepository, eventRegistrationService: mock.eventRegistrationService,
            newsRepository: mock.newsRepository, memberRepository: mock.memberRepository,
            feedRepository: mock.feedRepository, mentorshipRepository: mock.mentorshipRepository,
            scholarshipRepository: mock.scholarshipRepository,
            notificationRepository: FailingNotificationRepository(),
            isDemoEnvironment: false
        )
        let viewModel = NotificationsViewModel(environment: environment)
        await viewModel.load()
        let unread = viewModel.unreadCount
        XCTAssertGreaterThan(unread, 0)

        await viewModel.markAllRead()
        XCTAssertEqual(viewModel.unreadCount, unread, "A failed update must not appear to succeed")
        XCTAssertNotNil(viewModel.errorMessage)

        let first = viewModel.notifications.first { !$0.isRead }!
        await viewModel.markRead(first)
        XCTAssertEqual(viewModel.unreadCount, unread)
    }
}

private struct FailingNotificationRepository: NotificationRepository {
    func fetchNotifications() async throws -> [AppNotification] { AppNotification.examples }
    func markAllRead() async throws { throw AppError.unauthorized }
    func markRead(id: UUID) async throws { throw AppError.unauthorized }
}

// MARK: - Mentorship navigation (hosted window, accessibility activation)

@MainActor
final class MentorshipNavigationTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func host<Content: View>(_ content: Content) throws -> UIWindow {
        let state = AppState(environment: .makeMock())
        state.currentUser = AuthUser(id: MemberProfile.demo.id, email: "synthetic@example.com", role: .member)
        state.isAuthenticated = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = UIHostingController(rootView: content.environment(state))
        window.makeKeyAndVisible()
        self.window = window
        settle()
        return window
    }

    private func settle(_ seconds: TimeInterval = 1.2) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func navigationController(in controller: UIViewController?) -> UINavigationController? {
        guard let controller else { return nil }
        if let nav = controller as? UINavigationController { return nav }
        for child in controller.children {
            if let nav = navigationController(in: child) { return nav }
        }
        return navigationController(in: controller.presentedViewController)
    }

    private func titles(_ window: UIWindow) -> [String] {
        navigationController(in: window.rootViewController)?.viewControllers.map { $0.navigationItem.title ?? "?" } ?? []
    }

    private func element(labelPrefix: String, in object: NSObject) -> NSObject? {
        if let label = object.accessibilityLabel, label.hasPrefix(labelPrefix), object.isAccessibilityElement,
           object.accessibilityTraits.contains(.button) { return object }
        var children: [NSObject] = []
        if let elements = object.accessibilityElements as? [NSObject] { children += elements }
        let count = object.accessibilityElementCount()
        if count != NSNotFound, count > 0 {
            children += (0..<count).compactMap { object.accessibilityElement(at: $0) as? NSObject }
        }
        if let view = object as? UIView { children += view.subviews }
        for child in children {
            if let found = element(labelPrefix: labelPrefix, in: child) { return found }
        }
        return nil
    }

    private func activate(_ labelPrefix: String, in window: UIWindow, file: StaticString = #filePath, line: UInt = #line) {
        guard let target = element(labelPrefix: labelPrefix, in: window) else {
            XCTFail("No accessible element starting with \"\(labelPrefix)\"", file: file, line: line)
            return
        }
        XCTAssertTrue(target.accessibilityActivate(), "Could not activate \(labelPrefix)", file: file, line: line)
        settle()
    }

    private func pop(_ window: UIWindow) {
        navigationController(in: window.rootViewController)?.popViewController(animated: false)
        settle()
    }

    /// Opens Mentorship from an entry point, then exercises both call-to-action buttons.
    private func assertMentorshipButtons(from window: UIWindow, entry: String, line: UInt = #line) {
        activate(entry, in: window, line: line)
        XCTAssertEqual(titles(window).last, "Mentorship", "entry \(entry)", line: line)
        let base = titles(window).count

        activate("Find a Mentor", in: window, line: line)
        XCTAssertEqual(titles(window).last, "Find a Mentor", "stack: \(titles(window))", line: line)
        XCTAssertEqual(titles(window).count, base + 1, "Exactly one screen is pushed", line: line)
        pop(window)
        XCTAssertEqual(titles(window).last, "Mentorship", line: line)

        activate("Become a Mentor", in: window, line: line)
        XCTAssertEqual(titles(window).last, "Become a Mentor", "stack: \(titles(window))", line: line)
        pop(window)
        XCTAssertEqual(titles(window).last, "Mentorship", line: line)

        activate("Find a Mentor", in: window, line: line)
        XCTAssertEqual(titles(window).last, "Find a Mentor", "Reopening must not loop back: \(titles(window))", line: line)
        XCTAssertEqual(titles(window).count, base + 1, "No duplicate screens after returning", line: line)
    }

    func testConnectMentorshipButtonsOpenTheirOwnScreens() throws {
        let window = try host(ExploreMenuView())
        assertMentorshipButtons(from: window, entry: "Mentorship")
    }

    func testHomeMentorshipButtonsOpenTheirOwnScreens() throws {
        let window = try host(HomeView())
        assertMentorshipButtons(from: window, entry: "Find a Mentor")
    }

    func testYouMentorshipButtonsOpenTheirOwnScreens() throws {
        let window = try host(ProfileView())
        assertMentorshipButtons(from: window, entry: "Mentorship")
    }

    func testSavingMentorProfileTwiceUpdatesInsteadOfDuplicating() async {
        let viewModel = MentorshipViewModel(environment: .makeMock(), currentUserID: MemberProfile.demo.id)
        await viewModel.load()
        func settings(_ specialty: String, accepting: Bool) -> MentorDirectorySettings {
            MentorDirectorySettings(specialties: [specialty], bio: "Synthetic bio", careerField: "Logistics",
                                    careerBackground: "", interests: [], sharesChapter: false, isAccepting: accepting)
        }
        let created = await viewModel.becomeMentor(settings: settings("Leadership", accepting: true))
        XCTAssertTrue(created)
        let updated = await viewModel.becomeMentor(settings: settings("Career Transition", accepting: false))
        XCTAssertTrue(updated)
        let mine = viewModel.mentors.filter { $0.id == MemberProfile.demo.id }
        XCTAssertEqual(mine.count, 1)
        XCTAssertEqual(mine.first?.specialties, ["Career Transition"])
        XCTAssertEqual(mine.first?.isAcceptingMentees, false)

        let rejected = await viewModel.becomeMentor(settings: settings("  ", accepting: true))
        XCTAssertFalse(rejected, "A profile without a specialty is not saved")
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testMentorProfileReturnsToDiscovery() throws {
        let window = try host(ExploreMenuView())
        activate("Mentorship", in: window)
        activate("Find a Mentor", in: window)
        let mentor = try XCTUnwrap(MentorProfile.examples.first)
        activate(mentor.member.fullName, in: window)
        XCTAssertEqual(titles(window).last, "Mentor", "stack: \(titles(window))")
        pop(window)
        XCTAssertEqual(titles(window).last, "Find a Mentor")
        pop(window)
        activate("Find a Mentor", in: window)
        XCTAssertEqual(titles(window).last, "Find a Mentor", "Navigation still works after viewing a profile")
    }
}
