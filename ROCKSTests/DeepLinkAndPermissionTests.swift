import UserNotifications
import XCTest

@testable import ROCKS

final class DeepLinkAndPermissionTests: XCTestCase {
    func testDeepLinkParsesEventIdentifier() {
        let id = UUID()
        let route = DeepLinkRoute(url: URL(string: "rocks://event/\(id.uuidString)")!)

        XCTAssertEqual(route, .event(id))
    }

    func testGuestCannotRegisterForEvents() {
        XCTAssertFalse(AppRole.guest.can(.registerForEvents))
        XCTAssertTrue(AppRole.member.can(.registerForEvents))
    }

    func testChapterAdminCannotManageNationalContent() {
        XCTAssertTrue(AppRole.chapterAdmin.can(.manageChapterContent))
        XCTAssertFalse(AppRole.chapterAdmin.can(.manageNationalContent))
        XCTAssertTrue(AppRole.nationalAdmin.can(.manageNationalContent))
    }
}

@MainActor
final class OfficialCalendarTests: XCTestCase {
    private func event(id: UUID = UUID(), date: String, start: String? = nil, zone: String? = nil) -> OfficialEvent {
        OfficialEvent(
            id: id, title: "Test event", eventDate: date,
            startsAt: start.flatMap { ISO8601DateFormatter().date(from: $0) },
            endsAt: nil, timeZone: zone, location: nil, host: nil, description: nil,
            sourceURL: URL(string: "https://rocksinc.org/")!
        )
    }

    func testBundledEventsLoadWithoutConfiguration() async throws {
        let suite = "OfficialCalendarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bundled = try BundledEventSource.load()
        XCTAssertFalse(bundled.isEmpty)
        let store = OfficialCalendarStore(defaults: defaults, center: TestEventNotifications())
        await store.load()
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.events.map(\.id), bundled.map(\.id))
    }

    func testEmptyCalendarAndDateBasedCategories() async throws {
        let suite = "OfficialCalendarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = OfficialCalendarStore(defaults: defaults, center: TestEventNotifications())
        try await store.updateEvents([])
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(EventSection.allCases.allSatisfy { store.events(in: $0).isEmpty })
        let today = event(date: "2030-04-10", start: "2030-04-10T09:00:00Z", zone: "UTC")
        let yesterday = event(date: "2030-04-09")
        let older = event(date: "2030-04-08")
        let tomorrow = event(date: "2030-04-11")
        try await store.updateEvents([tomorrow, older, today, yesterday])
        let now = ISO8601DateFormatter().date(from: "2030-04-10T12:00:00Z")!
        XCTAssertEqual(store.events(in: .upcoming, at: now).map(\.id), [today.id, tomorrow.id])
        XCTAssertEqual(store.events(in: .past, at: now).map(\.id), [yesterday.id, older.id])
        try await store.schedule(.oneDay, for: tomorrow)
        XCTAssertEqual(store.events(in: .reminders, at: now).map(\.id), [tomorrow.id])
    }

    func testTimedReminderUsesEventZoneAcrossDaylightSavingChange() {
        let event = event(date: "2030-03-10", start: "2030-03-10T14:00:00Z", zone: "America/New_York")
        let expected = ISO8601DateFormatter().date(from: "2030-03-09T15:00:00Z")
        XCTAssertEqual(event.reminderDate(daysBefore: 1), expected)
    }

    func testDateOnlyUsesLocalNineAndRemainsUpcomingThroughItsDay() {
        let event = event(date: "2030-03-10")
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        let nine = ISO8601DateFormatter().date(from: "2030-03-10T16:00:00Z")
        XCTAssertEqual(event.reminderDate(daysBefore: 0, localTimeZone: zone), nine)
        XCTAssertTrue(
            event.isUpcoming(at: ISO8601DateFormatter().date(from: "2030-03-11T06:59:00Z")!, localTimeZone: zone))
        XCTAssertFalse(
            event.isUpcoming(at: ISO8601DateFormatter().date(from: "2030-03-11T07:00:00Z")!, localTimeZone: zone))
    }

    func testReminderCreateEditReloadRescheduleAndRemove() async throws {
        let suite = "OfficialCalendarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = TestEventNotifications()
        let first = event(date: "2030-04-10", start: "2030-04-10T14:00:00Z", zone: "America/New_York")
        let store = OfficialCalendarStore(defaults: defaults, center: notifications)
        try await store.updateEvents([first])
        try await store.schedule(.oneDay, for: first)
        XCTAssertEqual(store.timing(for: first), .oneDay)
        XCTAssertEqual(notifications.requests.count, 1)

        try await store.schedule(.threeDays, for: first)
        XCTAssertEqual(notifications.requests.count, 1)
        let restored = OfficialCalendarStore(defaults: defaults, center: notifications)
        XCTAssertEqual(restored.timing(for: first), .threeDays)
        let moved = event(id: first.id, date: "2030-04-12", start: "2030-04-12T14:00:00Z", zone: "America/New_York")
        try await restored.updateEvents([moved])
        let trigger = try XCTUnwrap(notifications.requests.values.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.nextTriggerDate(), moved.reminderDate(daysBefore: 3))
        try restored.remove(moved)
        XCTAssertTrue(notifications.requests.isEmpty)
        XCTAssertNil(OfficialCalendarStore(defaults: defaults, center: notifications).timing(for: moved))
    }

    func testDeniedPermissionAndPastReminderDoNotSave() async throws {
        let suite = "OfficialCalendarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = TestEventNotifications()
        notifications.status = .denied
        let store = OfficialCalendarStore(defaults: defaults, center: notifications)
        let future = event(date: "2030-04-10")
        do {
            try await store.schedule(.onDay, for: future)
            XCTFail("Denied notifications must not be scheduled")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("permission"))
        }
        XCTAssertNil(store.timing(for: future))
        XCTAssertTrue(notifications.requests.isEmpty)
        do {
            try await store.schedule(.oneWeek, for: event(date: "2020-01-01"))
            XCTFail("A past reminder must not be scheduled")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("passed"))
        }
    }

    func testPermissionRequestedOnlyForUserAction() async throws {
        let suite = "OfficialCalendarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = TestEventNotifications()
        notifications.status = .notDetermined
        notifications.grantOnRequest = true
        let store = OfficialCalendarStore(defaults: defaults, center: notifications)
        let future = event(date: "2030-04-10")
        try await store.updateEvents([future])
        XCTAssertEqual(notifications.permissionRequests, 0)
        try await store.schedule(.onDay, for: future)
        XCTAssertEqual(notifications.permissionRequests, 1)
        XCTAssertEqual(notifications.requests.count, 1)
    }

    func testLocalSnapshotSortsAndRemovesDeletedReminder() async throws {
        let suite = "OfficialCalendarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let notifications = TestEventNotifications()
        let store = OfficialCalendarStore(defaults: defaults, center: notifications)
        let later = event(date: "2030-04-12")
        let earlier = event(date: "2030-04-10")
        try await store.updateEvents([later, earlier])
        XCTAssertEqual(store.events.map(\.id), [earlier.id, later.id])
        try await store.schedule(.onDay, for: earlier)
        try await store.updateEvents([later])
        XCTAssertTrue(notifications.requests.isEmpty)
        XCTAssertNil(store.timing(for: earlier))
        XCTAssertNotNil(store.errorMessage)
    }

    func testNativeNotificationSchedulingWhenAuthorized() async throws {
        let notifications = SystemEventNotificationCenter()
        let status = await notifications.authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            throw XCTSkip("Simulator notification permission has not been granted.")
        }
        let suite = "OfficialCalendarTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = OfficialCalendarStore(defaults: defaults, center: notifications)
        let future = event(date: "2030-04-10")
        try await store.schedule(.oneDay, for: future)
        defer { notifications.remove(["official-event-\(future.id.uuidString)"]) }
        let pending = await notifications.pending()
        XCTAssertTrue(pending.contains { $0.identifier == "official-event-\(future.id.uuidString)" })
        try store.remove(future)
        let remaining = await notifications.pending()
        XCTAssertFalse(remaining.contains { $0.identifier == "official-event-\(future.id.uuidString)" })
    }
}

@MainActor
private final class TestEventNotifications: EventNotificationCenter {
    var status: UNAuthorizationStatus = .authorized
    var grantOnRequest = false
    var permissionRequests = 0
    var requests: [String: UNNotificationRequest] = [:]
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        permissionRequests += 1
        return grantOnRequest
    }
    func pending() async -> [UNNotificationRequest] { Array(requests.values) }
    func add(_ request: UNNotificationRequest) async throws { requests[request.identifier] = request }
    func remove(_ identifiers: [String]) { identifiers.forEach { requests.removeValue(forKey: $0) } }
}
