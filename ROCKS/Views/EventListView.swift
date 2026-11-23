import Observation
import SwiftUI
import UserNotifications

struct OfficialEvent: Decodable, Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let eventDate: String
    let startsAt: Date?
    let endsAt: Date?
    let timeZone: String?
    let location: String?
    let host: String?
    let description: String?
    let sourceURL: URL

    enum CodingKeys: String, CodingKey {
        case id, title, location, host, description
        case eventDate = "event_date"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case timeZone = "time_zone"
        case sourceURL = "source_url"
    }

    func calendar(in localTimeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            startsAt == nil ? localTimeZone : (timeZone.flatMap(TimeZone.init(identifier:)) ?? localTimeZone)
        return calendar
    }

    func date(in localTimeZone: TimeZone = .current) -> Date? {
        let fields = eventDate.split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count == 3, fields[0].count == 4, fields[1].count == 2, fields[2].count == 2,
            let year = Int(fields[0]), let month = Int(fields[1]), let day = Int(fields[2])
        else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        let calendar = calendar(in: localTimeZone)
        guard let date = calendar.date(from: components),
            calendar.component(.year, from: date) == year,
            calendar.component(.month, from: date) == month,
            calendar.component(.day, from: date) == day
        else { return nil }
        return date
    }

    func isUpcoming(at now: Date = .now, localTimeZone: TimeZone = .current) -> Bool {
        guard let day = date(in: localTimeZone),
            let tomorrow = calendar(in: localTimeZone).date(
                byAdding: .day, value: 1, to: calendar(in: localTimeZone).startOfDay(for: day))
        else { return false }
        return now < tomorrow
    }

    func reminderDate(daysBefore: Int, localTimeZone: TimeZone = .current) -> Date? {
        let calendar = calendar(in: localTimeZone)
        guard let day = date(in: localTimeZone) else { return nil }
        let base = startsAt ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day)
        guard let base else { return nil }
        return calendar.date(byAdding: .day, value: -daysBefore, to: base)
    }

    var dateLabel: String {
        guard let day = date() else { return eventDate }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeZone = calendar().timeZone
        return formatter.string(from: day)
    }

    var timeLabel: String? {
        guard let startsAt else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = calendar().timeZone
        let start = formatter.string(from: startsAt)
        let end =
            endsAt.map {
                if !calendar().isDate(startsAt, inSameDayAs: $0) { formatter.dateStyle = .medium }
                return " – \(formatter.string(from: $0))"
            } ?? ""
        return "\(start)\(end) (\(calendar().timeZone.identifier))"
    }
}

enum ReminderTiming: Int, CaseIterable, Codable {
    case onDay = 0
    case oneDay = 1
    case threeDays = 3
    case oneWeek = 7

    var title: String {
        switch self {
        case .onDay: "On the day of the event"
        case .oneDay: "1 day before"
        case .threeDays: "3 days before"
        case .oneWeek: "1 week before"
        }
    }
}

struct BundledEventSource {
    static func load(bundle: Bundle = .main) throws -> [OfficialEvent] {
        guard let url = bundle.url(forResource: "events", withExtension: "json") else {
            throw CalendarError.missingEventsFile
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([OfficialEvent].self, from: Data(contentsOf: url))
    }
}

@MainActor
protocol EventNotificationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func pending() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func remove(_ identifiers: [String])
}

@MainActor
struct SystemEventNotificationCenter: EventNotificationCenter {
    private let center = UNUserNotificationCenter.current()
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func remove(_ identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
}

@MainActor
@Observable
final class OfficialCalendarStore {
    static let shared = OfficialCalendarStore()
    private(set) var events: [OfficialEvent] = []
    private(set) var reminders: [String: ReminderTiming] = [:]
    private(set) var failedReminders: Set<String> = []
    private(set) var isLoading = false
    var errorMessage: String?
    private let defaults: UserDefaults
    private let center: any EventNotificationCenter
    private let storageKey = "officialEventReminders"
    private var storageReadFailed = false

    init(defaults: UserDefaults = .standard, center: (any EventNotificationCenter)? = nil) {
        self.defaults = defaults
        self.center = center ?? SystemEventNotificationCenter()
        if let data = defaults.data(forKey: storageKey) {
            do {
                reminders = try JSONDecoder().decode([String: ReminderTiming].self, from: data)
            } catch {
                storageReadFailed = true
                errorMessage = "Saved reminders could not be read. They have not been changed."
            }
        }
    }

    func load(bundle: Bundle = .main) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await updateEvents(BundledEventSource.load(bundle: bundle))
        } catch {
            errorMessage = "The bundled calendar could not be loaded: \(error.localizedDescription)"
        }
    }

    func events(in section: EventSection, at now: Date = .now) -> [OfficialEvent] {
        switch section {
        case .upcoming: events.filter { $0.isUpcoming(at: now) }
        case .past: events.filter { !$0.isUpcoming(at: now) }.reversed()
        case .reminders: events.filter { timing(for: $0) != nil }
        }
    }

    func updateEvents(_ fetched: [OfficialEvent]) async throws {
        guard Set(fetched.map(\.id)).count == fetched.count else {
            throw CalendarError.invalidEvent("duplicate event ID")
        }
        for event in fetched {
            guard event.date() != nil,
                event.startsAt == nil || (event.timeZone.flatMap(TimeZone.init(identifier:)) != nil),
                event.endsAt.map({ end in event.startsAt.map { end >= $0 } ?? false }) ?? true,
                event.sourceURL.scheme == "https",
                let host = event.sourceURL.host?.lowercased(),
                host == "rocksinc.org" || host.hasSuffix(".rocksinc.org")
            else {
                throw CalendarError.invalidEvent(event.title)
            }
            if let start = event.startsAt, let day = event.date(),
                !event.calendar().isDate(start, inSameDayAs: day)
            {
                throw CalendarError.invalidEvent(event.title)
            }
        }
        events = fetched.sorted {
            if $0.eventDate != $1.eventDate { return $0.eventDate < $1.eventDate }
            return ($0.startsAt ?? .distantPast) < ($1.startsAt ?? .distantPast)
        }
        if storageReadFailed {
            errorMessage = "Saved reminders could not be read. They have not been changed."
        } else {
            errorMessage = nil
            await reconcile()
        }
    }

    func timing(for event: OfficialEvent) -> ReminderTiming? { reminders[event.id.uuidString] }

    func schedule(_ timing: ReminderTiming, for event: OfficialEvent, requestPermission: Bool = true) async throws {
        guard !isLoading || !requestPermission else { throw CalendarError.refreshing }
        guard !storageReadFailed else { throw CalendarError.savedRemindersUnreadable }
        guard let fireDate = event.reminderDate(daysBefore: timing.rawValue), fireDate > .now else {
            throw CalendarError.reminderInPast
        }
        let status = await center.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            guard requestPermission else { throw CalendarError.notificationsDenied }
            guard try await center.requestAuthorization() else {
                throw CalendarError.notificationsDenied
            }
        case .denied:
            throw CalendarError.notificationsDenied
        @unknown default:
            throw CalendarError.notificationsDenied
        }
        let identifier = notificationID(event.id)
        let pending = await center.pending()
        guard pending.count < 64 || pending.contains(where: { $0.identifier == identifier }) else {
            throw CalendarError.tooManyReminders
        }
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "\(timing.title) · \(event.dateLabel)"
        content.sound = .default
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        reminders[event.id.uuidString] = timing
        failedReminders.remove(event.id.uuidString)
        try save()
    }

    func remove(_ event: OfficialEvent) throws {
        guard !isLoading else { throw CalendarError.refreshing }
        guard !storageReadFailed else { throw CalendarError.savedRemindersUnreadable }
        center.remove([notificationID(event.id)])
        reminders.removeValue(forKey: event.id.uuidString)
        failedReminders.remove(event.id.uuidString)
        try save()
    }

    private func reconcile() async {
        let eventByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id.uuidString, $0) })
        let saved = reminders
        for (id, timing) in saved {
            guard let uuid = UUID(uuidString: id) else {
                errorMessage = "A saved reminder has an invalid event identifier."
                continue
            }
            guard let event = eventByID[id] else {
                center.remove([notificationID(uuid)])
                reminders.removeValue(forKey: id)
                failedReminders.remove(id)
                errorMessage = "An event was removed from the bundled calendar; its reminder was removed."
                continue
            }
            guard event.isUpcoming() else {
                center.remove([notificationID(uuid)])
                reminders.removeValue(forKey: id)
                failedReminders.remove(id)
                continue
            }
            guard let fireDate = event.reminderDate(daysBefore: timing.rawValue), fireDate > .now else {
                center.remove([notificationID(uuid)])
                reminders.removeValue(forKey: id)
                failedReminders.remove(id)
                errorMessage = "The reminder time for \(event.title) has passed. Choose a later reminder."
                continue
            }
            do {
                try await schedule(timing, for: event, requestPermission: false)
            } catch {
                center.remove([notificationID(uuid)])
                failedReminders.insert(id)
                errorMessage = "A reminder for \(event.title) could not be updated: \(error.localizedDescription)"
            }
        }
        do { try save() } catch { errorMessage = "Reminders could not be saved: \(error.localizedDescription)" }
    }

    private func notificationID(_ id: UUID) -> String { "official-event-\(id.uuidString)" }
    private func save() throws { defaults.set(try JSONEncoder().encode(reminders), forKey: storageKey) }
}

private enum CalendarError: LocalizedError {
    case invalidEvent(String)
    case reminderInPast, notificationsDenied, tooManyReminders, savedRemindersUnreadable, refreshing, missingEventsFile
    var errorDescription: String? {
        switch self {
        case .invalidEvent(let title): "Invalid bundled calendar data for \(title). Please contact support."
        case .reminderInPast: "That reminder time has passed. Choose a later reminder."
        case .notificationsDenied:
            "Notification permission is required for reminders. Enable notifications for ROCKS in Settings."
        case .tooManyReminders: "The iOS notification limit has been reached. Remove a reminder and try again."
        case .savedRemindersUnreadable: "Saved reminders could not be read, so they cannot be changed."
        case .refreshing: "The calendar is refreshing. Try again when it finishes."
        case .missingEventsFile: "The app's events.json resource is missing. Please contact support."
        }
    }
}

enum EventSection: String, CaseIterable {
    case upcoming = "Upcoming Events"
    case past = "Past Events"
    case reminders = "My Reminders"
}

struct EventListView: View {
    let isEmbedded: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = OfficialCalendarStore.shared
    @State private var section: EventSection = .upcoming
    @State private var calendarView = false
    @State private var month = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay: Date?

    init(isEmbedded: Bool = false) {
        self.isEmbedded = isEmbedded
    }

    private var visibleEvents: [OfficialEvent] {
        let events = store.events(in: section)
        guard calendarView else { return events }
        guard let selectedDay else { return [] }
        let key = dayKey(selectedDay)
        return events.filter { $0.eventDate == key }
    }

    var body: some View {
        Group {
            if isEmbedded {
                eventContent
            } else {
                NavigationStack { eventContent }
            }
        }
    }

    private var eventContent: some View {
        ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MAKE TIME TO CONNECT")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(ROCKSColor.goldText)
                        Text("Show up. Grow together.")
                            .font(ROCKSFont.title)
                            .foregroundStyle(ROCKSColor.primaryText)
                        Text("Browse verified events and set personal reminders.")
                            .font(.subheadline)
                            .foregroundStyle(ROCKSColor.subtleText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Events", selection: $section) {
                        ForEach(EventSection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("View", selection: $calendarView) {
                        Text("List View").tag(false)
                        Text("Calendar View").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if let message = store.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(ROCKSColor.subtleText).frame(
                            maxWidth: .infinity, alignment: .leading)
                    }
                    if store.isLoading { ProgressView() }
                    if calendarView { calendarGrid }
                    if visibleEvents.isEmpty && !store.isLoading {
                        Text(
                            store.events.isEmpty ? "No ROCKS events are currently available."
                                : (calendarView && selectedDay == nil
                                    ? "Select a date to see its events." : "No ROCKS events are currently available.")
                        )
                        .foregroundStyle(ROCKSColor.subtleText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(visibleEvents) { event in
                        NavigationLink {
                            OfficialEventDetailView(event: event, store: store)
                        } label: {
                            eventCard(event)
                        }.buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(ROCKSColor.background)
            .navigationTitle("Events")
            .task { await store.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.load() } }
            }
    }

    private func eventCard(_ event: OfficialEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(ROCKSColor.goldText)
                .frame(width: 48, height: 48)
                .background(ROCKSColor.insetBackground, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title).font(.headline).foregroundStyle(ROCKSColor.primaryText)
                Text(event.dateLabel).foregroundStyle(ROCKSColor.goldText)
                if let time = event.timeLabel { Text(time).foregroundStyle(ROCKSColor.subtleText) }
                if let location = event.location { Text(location).foregroundStyle(ROCKSColor.subtleText) }
                if let description = event.description {
                    Text(description)
                        .foregroundStyle(ROCKSColor.subtleText)
                        .lineLimit(3)
                }
                if let timing = store.timing(for: event), section == .reminders {
                    Text(
                        store.failedReminders.contains(event.id.uuidString) ? "Reminder needs attention" : timing.title
                    )
                    .font(.caption).foregroundStyle(ROCKSColor.subtleText)
                }
            }.font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(ROCKSColor.goldText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ROCKSColor.divider))
    }

    private var calendarGrid: some View {
        let calendar = displayCalendar
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let count = calendar.range(of: .day, in: .month, for: start)!.count
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let symbols = calendar.shortWeekdaySymbols
        let marked = Set(
            store.events(in: section).map(\.eventDate))
        return VStack(spacing: 10) {
            HStack {
                Button {
                    month = calendar.date(byAdding: .month, value: -1, to: start)!
                    selectedDay = nil
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(start.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                Button {
                    month = calendar.date(byAdding: .month, value: 1, to: start)!
                    selectedDay = nil
                } label: {
                    Image(systemName: "chevron.right")
                }
            }.foregroundStyle(ROCKSColor.goldText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    Text(symbols[(calendar.firstWeekday - 1 + index) % 7]).font(.caption)
                }
                ForEach(0..<(leading + count), id: \.self) { index in
                    if index < leading {
                        Color.clear.frame(height: 40)
                    } else {
                        let day = calendar.date(byAdding: .day, value: index - leading, to: start)!
                        Button {
                            selectedDay = day
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(index - leading + 1)")
                                Circle().fill(marked.contains(dayKey(day)) ? ROCKSColor.gold : .clear).frame(
                                    width: 5, height: 5)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                selectedDay.map { calendar.isDate($0, inSameDayAs: day) } == true
                                    ? ROCKSColor.gold.opacity(0.25) : .clear, in: Circle())
                        }
                        .foregroundStyle(ROCKSColor.primaryText)
                        .accessibilityLabel(
                            "\(day.formatted(date: .long, time: .omitted))\(marked.contains(dayKey(day)) ? ", has events" : "")"
                        )
                    }
                }
            }
        }.padding().background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func dayKey(_ date: Date) -> String {
        let parts = displayCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    private var displayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = .current
        return calendar
    }
}

struct OfficialEventDetailView: View {
    let event: OfficialEvent
    let store: OfficialCalendarStore
    @State private var showingOptions = false
    @State private var error: String?
    @State private var presentedLink: IdentifiableURL?

    var body: some View {
        ScrollView {
            if let event = store.events.first(where: { $0.id == event.id }) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(event.title).font(.largeTitle.weight(.bold)).foregroundStyle(ROCKSColor.primaryText)
                    Label(event.dateLabel, systemImage: "calendar")
                    if let time = event.timeLabel { Label(time, systemImage: "clock") }
                    if let location = event.location { Label(location, systemImage: "location") }
                    if let host = event.host { Label(host, systemImage: "person.2") }
                    if let description = event.description {
                        Divider()
                        Text(description)
                    }
                    OfficialLinkRow(title: "Official event information", subtitle: "View the verified ROCKS calendar source", systemImage: "arrow.up.right.square") {
                        presentedLink = IdentifiableURL(url: event.sourceURL)
                    }
                    if event.startsAt == nil {
                        Text("No start time is published. Reminders use 9:00 AM in your local time zone.")
                            .font(.footnote).foregroundStyle(ROCKSColor.subtleText)
                    }
                    if let message = error ?? store.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(ROCKSColor.subtleText)
                    }
                    if event.isUpcoming() {
                        Button {
                            showingOptions = true
                        } label: {
                            Label(
                                store.failedReminders.contains(event.id.uuidString)
                                    ? "Reminder Needs Attention"
                                    : (store.timing(for: event) == nil ? "Remind Me" : "Reminder Set ✓"),
                                systemImage: "bell"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).tint(ROCKSColor.gold).foregroundStyle(ROCKSColor.black)
                    }
                }.padding()
            } else {
                Text("This event is no longer available.").padding()
            }
        }
        .background(ROCKSColor.background)
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .officialLinkSheet($presentedLink)
        .confirmationDialog("Reminder timing", isPresented: $showingOptions, titleVisibility: .visible) {
            ForEach(ReminderTiming.allCases, id: \.self) { timing in
                Button(timing.title) {
                    Task {
                        guard let current = store.events.first(where: { $0.id == event.id }) else {
                            error = "This event is no longer available."
                            return
                        }
                        do {
                            try await store.schedule(timing, for: current)
                            error = nil
                        } catch { self.error = error.localizedDescription }
                    }
                }
            }
            if store.timing(for: event) != nil {
                Button("Remove Reminder", role: .destructive) {
                    do {
                        try store.remove(event)
                        error = nil
                    } catch { self.error = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
