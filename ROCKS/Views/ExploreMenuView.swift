import SwiftUI

private struct DonateDestination: Hashable {}

/// Connect brings the community and member tools together without exposing private profiles.
struct ExploreMenuView: View {
    @Environment(AppState.self) private var appState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: ROCKSTheme.spacingMD) {
                    connectHeader
                    connectDestinations
                    NavigationLink {
                        moreResources
                    } label: {
                        directoryCard(title: "More from ROCKS", subtitle: "Organization information, resources, giving, and member tools.", systemImage: "square.grid.2x2")
                    }
                    .buttonStyle(ROCKSPressStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(ROCKSColor.background)
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Chapter.self) { chapter in
                ChapterDetailView(chapter: chapter)
            }
            .navigationDestination(for: NewsArticle.self) { article in
                NewsDetailView(article: article)
            }
            .navigationDestination(for: Scholarship.self) { scholarship in
                ScholarshipDetailView(scholarship: scholarship)
            }
            .navigationDestination(for: DonateDestination.self) { _ in
                DonateView()
            }
        }
        .onChange(of: appState.pendingDeepLink) { _, route in
            guard let route else { return }
            switch route {
            case .chapter(let id):
                appState.pendingDeepLink = nil
                Task {
                    if let chapter = try? await appState.environment.chapterRepository.fetchChapter(id: id) {
                        path.append(chapter)
                    }
                }
            case .news(let id):
                appState.pendingDeepLink = nil
                Task {
                    if let article = try? await appState.environment.newsRepository.fetchArticle(id: id) {
                        path.append(article)
                    }
                }
            case .scholarship(let id):
                appState.pendingDeepLink = nil
                Task {
                    let scholarships = try? await appState.environment.scholarshipRepository.fetchActiveScholarships()
                    if let scholarship = scholarships?.first(where: { $0.id == id }) {
                        path.append(scholarship)
                    }
                }
            case .event, .mentor:
                break
            }
        }
    }

    private var connectHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONNECTION. MENTORSHIP. COMMUNITY.")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(ROCKSColor.goldText)
            Text("Find your people.")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(ROCKSColor.primaryText)
            Text("Connect with the ROCKS community, explore mentorship, and find your chapter.")
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var connectDestinations: some View {
        VStack(spacing: 10) {
            NavigationLink(destination: CommunityView()) {
                directoryCard(title: "Community Board", subtitle: "Share updates and join the conversation.", systemImage: "bubble.left.and.bubble.right")
            }
            NavigationLink(destination: MentorshipHomeView()) {
                directoryCard(title: "Mentorship", subtitle: "Find a mentor and view your connections.", systemImage: "person.2")
            }
            NavigationLink(destination: MemberDirectoryView()) {
                directoryCard(title: "Member Directory", subtitle: "Discover members through the authorized directory.", systemImage: "person.3")
            }
            NavigationLink(destination: ChapterListView()) {
                directoryCard(title: "Chapters", subtitle: "Find chapters and interest groups near you.", systemImage: "mappin.and.ellipse")
            }
        }
        .buttonStyle(.plain)
    }

    private var moreResources: some View {
        ScrollView {
            VStack(spacing: ROCKSTheme.spacingMD) {
                brandedHeader
                directorySection
                memberToolsSection
                profileCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("More from ROCKS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var brandedHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            ROCKSLogoHeader(size: .large, showsTagline: true)
            Text("Explore ROCKS")
                .font(ROCKSFont.titleSmall)
                .foregroundStyle(ROCKSColor.onDarkText)
            Text("Discover the programs, resources, and opportunities that support the ROCKS mission.")
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.onDarkText.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient.rocksBranded, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(ROCKSColor.goldStroke, lineWidth: 1))
        .padding(.top, 8)
    }

    private var directorySection: some View {
        VStack(spacing: 10) {
            NavigationLink(destination: AboutRocksView()) {
                directoryCard(title: "About ROCKS", subtitle: "Learn about the organization's mission, vision, values, and core competencies.", systemImage: "info.circle.fill")
            }
            .buttonStyle(.plain)

            tabDirectoryCard(
                title: "Programs",
                subtitle: "Explore leadership development, mentorship, networking, and outreach.",
                systemImage: "briefcase.fill",
                tab: .learn
            )

            NavigationLink(destination: MembershipView()) {
                directoryCard(title: "Membership", subtitle: "Learn about the ROCKS community and membership information.", systemImage: "person.badge.key.fill")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ChapterListView()) {
                directoryCard(title: "Chapters", subtitle: "Discover what chapters do and find a group near you.", systemImage: "mappin.and.ellipse")
            }
            .buttonStyle(.plain)

            NavigationLink {
                directoryGuide(
                    title: "Events",
                    text: "The Events tab shows records verified against the official ROCKS calendar and included with the app. Browse upcoming and past events in list or calendar view, or set a personal reminder.",
                    buttonTitle: "Open Events Calendar",
                    tab: .events
                )
            } label: {
                directoryCard(title: "Events", subtitle: "Browse the ROCKS calendar and view upcoming activities.", systemImage: "calendar")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ResourcesView()) {
                directoryCard(title: "Resources", subtitle: "Find additional information and official organizational links.", systemImage: "book.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private func directoryGuide(title: String, text: String, buttonTitle: String, tab: AppTab) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ROCKSCard {
                    Text(text)
                        .foregroundStyle(ROCKSColor.subtleText)
                }
                tabDirectoryCard(title: buttonTitle, subtitle: "Switch to the \(title) tab.", systemImage: "arrow.right.circle", tab: tab)
            }
            .padding(20)
        }
        .background(ROCKSColor.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tabDirectoryCard(title: String, subtitle: String, systemImage: String, tab: AppTab) -> some View {
        Button {
            appState.selectedTab = tab
        } label: {
            directoryCard(title: title, subtitle: subtitle, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func directoryCard(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ROCKSColor.goldText)
                .frame(width: 44, height: 44)
                .background(ROCKSColor.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ROCKSColor.primaryText)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ROCKSColor.goldText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var memberToolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("More from ROCKS")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ROCKSColor.primaryText)
                .padding(.horizontal, 4)
            VStack(spacing: 2) {
                tabRow(title: "Home", systemImage: "house.fill", tab: .home)
                NavigationLink(destination: MemberDirectoryView()) {
                    ROCKSMenuRow(title: "Members Directory", systemImage: "person.2.fill")
                }
                .buttonStyle(.plain)
                NavigationLink(destination: MentorshipHomeView()) {
                    ROCKSMenuRow(title: "Mentorship", systemImage: "figure.2.and.child.holdinghands")
                }
                .buttonStyle(.plain)
                NavigationLink(destination: CommunityView()) {
                    ROCKSMenuRow(title: "Community", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .buttonStyle(.plain)
                if appState.environment.isLive,
                   appState.currentUser?.role.can(.manageChapterContent) == true {
                    NavigationLink(destination: AdminDashboardView()) {
                        ROCKSMenuRow(title: "Admin Dashboard", systemImage: "lock.shield")
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink(destination: ScholarshipsView()) {
                    ROCKSMenuRow(title: "Scholarships", systemImage: "graduationcap.fill")
                }
                .buttonStyle(.plain)
                NavigationLink(destination: MediaView()) {
                    ROCKSMenuRow(title: "Media", systemImage: "play.rectangle.fill")
                }
                .buttonStyle(.plain)
                Button {
                    path.append(DonateDestination())
                } label: {
                    ROCKSMenuRow(
                        title: "Donate",
                        systemImage: "heart.fill",
                        goldAccent: true
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
            .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
        }
    }

    private func tabRow(title: String, systemImage: String, tab: AppTab) -> some View {
        Button {
            appState.selectedTab = tab
        } label: {
            ROCKSMenuRow(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private var profileCard: some View {
        NavigationLink(destination: ProfileView()) {
            HStack(spacing: 12) {
                ROCKSAvatar(name: appState.currentMember?.fullName ?? "ROCKS Member", url: appState.currentMember?.avatarURL, size: .md)
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Profile")
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.onDarkText)
                    Text(appState.currentMember?.fullName ?? appState.currentUser?.email ?? "")
                        .font(.caption)
                        .foregroundStyle(ROCKSColor.onDarkText.opacity(0.75))
                }
                Spacer()
                Image(systemName: "gearshape")
                    .foregroundStyle(ROCKSColor.goldLight)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(LinearGradient.rocksBranded.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.goldStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct AdminDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var chapters: [Chapter] = []
    @State private var activity: [AdministrativeActivity] = []
    @State private var applications: [MembershipApplication] = []
    @State private var reports: [ContentReport] = []
    @State private var applicationStatus: MembershipStatus = .pending
    @State private var pendingDecision: (MembershipApplication, MembershipDecision)?
    @State private var busyIDs: Set<UUID> = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var actionError: String?

    private var isNationalAdmin: Bool { appState.currentUser?.role == .nationalAdmin }

    var body: some View {
        List {
            Section("Overview") {
                Text(isNationalAdmin
                    ? "National administration: all membership applications, chapters, and reported content."
                    : "Chapter administration: applications that requested your chapter, and your chapter details.")
                Text("Every decision is enforced and recorded by the server.")
                    .foregroundStyle(.secondary)
            }
            if let actionError {
                Section { Text(actionError).foregroundStyle(.red) }
            }
            if isLoading {
                LoadingView()
            } else if let error {
                ErrorStateView(message: error) { Task { await load() } }
            } else {
                membershipSection
                if isNationalAdmin { moderationSection }
                chaptersSection
                activitySection
            }
        }
        .navigationTitle("Admin Dashboard")
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: applicationStatus) { _, _ in Task { await loadApplications() } }
        .confirmationDialog(
            decisionTitle,
            isPresented: Binding(get: { pendingDecision != nil }, set: { if !$0 { pendingDecision = nil } }),
            titleVisibility: .visible,
            presenting: pendingDecision
        ) { item in
            Button(decisionButton(item.1), role: item.1 == .approve ? nil : .destructive) {
                Task { await review(item.0, item.1) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("\(item.0.fullName) (\(item.0.email)) will be notified in the app.")
        }
    }

    private var membershipSection: some View {
        Section {
            Picker("Status", selection: $applicationStatus) {
                Text("Pending").tag(MembershipStatus.pending)
                Text("Approved").tag(MembershipStatus.approved)
                Text("Suspended").tag(MembershipStatus.suspended)
                Text("Declined").tag(MembershipStatus.declined)
            }
            .pickerStyle(.segmented)
            if applications.isEmpty {
                Text("No \(applicationStatus.rawValue) accounts in your scope.")
                    .foregroundStyle(.secondary)
            }
            ForEach(applications) { application in
                VStack(alignment: .leading, spacing: 6) {
                    Text(application.fullName).font(.headline)
                    Text(application.email).font(.subheadline).foregroundStyle(.secondary)
                    Text("Requested chapter: \(application.requestedChapterName ?? "None selected")")
                        .font(.caption)
                    Text(application.termsAcceptedAt == nil ? "Acknowledgment: not recorded" : "Acknowledgment accepted")
                        .font(.caption)
                        .foregroundStyle(application.termsAcceptedAt == nil ? .red : .secondary)
                    Text("Registered \(application.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                    HStack {
                        ForEach(decisions(for: application.status), id: \.rawValue) { decision in
                            Button(decisionButton(decision)) { pendingDecision = (application, decision) }
                                .buttonStyle(.bordered)
                                .tint(decision == .approve ? ROCKSColor.goldText : .red)
                        }
                        if busyIDs.contains(application.id) { ProgressView() }
                    }
                    .disabled(busyIDs.contains(application.id))
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Membership")
        } footer: {
            Text("Approval grants member access and assigns the requested chapter. Suspension removes member access and hides any mentor profile.")
        }
    }

    private var moderationSection: some View {
        Section {
            if reports.isEmpty {
                Text("No open reports.").foregroundStyle(.secondary)
            }
            ForEach(reports) { report in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(report.postID != nil ? "Post" : "Comment") \u{2022} \(report.reasonTitle)")
                        .font(.headline)
                    if report.reportCount > 1 {
                        Text("\(report.reportCount) open reports").font(.caption).foregroundStyle(.red)
                    }
                    Text(report.content ?? "Content no longer available")
                        .font(.subheadline)
                        .lineLimit(4)
                    Text("By \(report.authorName ?? "Unknown member") \u{2022} reported \(report.reportedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                    HStack {
                        Button("Remove Content", role: .destructive) { Task { await moderate(report) { try await $0.removeReportedContent(report) } } }
                            .buttonStyle(.bordered)
                        Button("Keep (Dismiss)") { Task { await moderate(report) { try await $0.resolveReport(id: report.id, dismissed: true) } } }
                            .buttonStyle(.bordered)
                        if busyIDs.contains(report.id) { ProgressView() }
                    }
                    .disabled(busyIDs.contains(report.id))
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Reported Content")
        } footer: {
            Text("Removing content permanently deletes it and closes its reports.")
        }
    }

    private var chaptersSection: some View {
        Section("Chapters") {
            if chapters.isEmpty {
                Text("No chapter is assigned to this administrator.")
            }
            ForEach(chapters) { chapter in
                NavigationLink(chapter.name) {
                    AdminChapterEditor(chapter: chapter) { await load() }
                }
            }
        }
    }

    private var activitySection: some View {
        Section("Administrative Activity (latest 50)") {
            if activity.isEmpty {
                Text("No activity available in your scope.")
            }
            ForEach(activity) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.resourceType.replacingOccurrences(of: "_", with: " ").capitalized): \(item.action.capitalized)")
                        .font(.headline)
                    Text("Target: \(item.resourceID.uuidString)")
                    Text("Actor: \(item.actorID?.uuidString ?? "System or external administration")")
                    Text(item.occurredAt, style: .date)
                    Text(item.occurredAt, style: .time)
                }
                .font(.caption)
                .foregroundStyle(ROCKSColor.subtleText)
            }
        }
    }

    private var decisionTitle: String {
        guard let decision = pendingDecision?.1 else { return "" }
        return "\(decisionButton(decision)) this account?"
    }

    private func decisions(for status: MembershipStatus) -> [MembershipDecision] {
        switch status {
        case .pending: [.approve, .decline]
        case .approved: [.suspend]
        case .suspended, .declined: [.approve]
        }
    }

    private func decisionButton(_ decision: MembershipDecision) -> String {
        switch decision {
        case .approve: "Approve"
        case .decline: "Decline"
        case .suspend: "Suspend"
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let repository = appState.environment.adminRepository
            async let loadedChapters = repository.fetchManagedChapters()
            async let loadedActivity = repository.fetchActivity()
            async let loadedApplications = repository.fetchMembershipApplications(status: applicationStatus)
            async let loadedReports = repository.fetchOpenReports()
            chapters = try await loadedChapters
            activity = try await loadedActivity
            applications = try await loadedApplications
            reports = try await loadedReports
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadApplications() async {
        do {
            applications = try await appState.environment.adminRepository.fetchMembershipApplications(status: applicationStatus)
            actionError = nil
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func review(_ application: MembershipApplication, _ decision: MembershipDecision) async {
        busyIDs.insert(application.id)
        defer { busyIDs.remove(application.id) }
        do {
            try await appState.environment.adminRepository.reviewMembership(profileID: application.id, decision: decision)
            applications.removeAll { $0.id == application.id }
            actionError = nil
            activity = (try? await appState.environment.adminRepository.fetchActivity()) ?? activity
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func moderate(_ report: ContentReport, _ action: (any AdminRepository) async throws -> Void) async {
        busyIDs.insert(report.id)
        defer { busyIDs.remove(report.id) }
        do {
            try await action(appState.environment.adminRepository)
            reports = try await appState.environment.adminRepository.fetchOpenReports()
            actionError = nil
        } catch {
            actionError = error.localizedDescription
        }
    }
}

private struct AdminChapterEditor: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let chapter: Chapter
    let onSave: () async -> Void
    @State private var description: String
    @State private var email: String
    @State private var website: String
    @State private var isSaving = false
    @State private var error: String?

    init(chapter: Chapter, onSave: @escaping () async -> Void) {
        self.chapter = chapter
        self.onSave = onSave
        _description = State(initialValue: chapter.description)
        _email = State(initialValue: chapter.email ?? "")
        _website = State(initialValue: chapter.website?.absoluteString ?? "")
    }

    var body: some View {
        Form {
            Section(chapter.name) {
                TextField("Description", text: $description, axis: .vertical)
                TextField("Contact email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("HTTPS website", text: $website)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if let error {
                Text(error).foregroundStyle(.red)
            }
            Button(isSaving ? "Saving..." : "Save") {
                Task { await save() }
            }
            .disabled(isSaving)
        }
        .navigationTitle("Edit Chapter")
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.environment.adminRepository.updateChapter(
                id: chapter.id, description: description, email: email, website: website
            )
            await onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct AboutRocksView: View {
    @State private var presentedLink: IdentifiableURL?

    private let coreCompetencies = [
        "Mentorship and Professional Development",
        "Leadership Outreach and ROTC Enhancement",
        "Scholarship",
        "Community Involvement/Outreach",
        "Networking"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                aboutCard(title: "Organizational Background", text: "The ROCKS, Inc. serves officers, ROTC cadets, future officers, and senior government civilians. The founders considered mentorship and professional development central concerns; the organization promotes mentoring through its chapters and interest groups.")
                aboutCard(title: "Mission", text: "The ROCKS strengthens the Officer and Senior Civilian Corps across the U.S. Armed Forces through mentoring, coaching, scholarships, networking, leadership diversity, professional development, and outreach.")
                aboutCard(title: "Vision", text: "The ROCKS aims to be a leading organization for mentorship, professional development, and networking for U.S. Armed Forces officers and senior civilians.")
                aboutCard(title: "Values", text: "Resourcefulness, Officership, Commitment, Knowledge, Scholarship, Integrity, Nerve, and Camaraderie.")
                ROCKSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Core Competencies")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(ROCKSColor.primaryText)
                        ForEach(coreCompetencies, id: \.self) { competency in
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(ROCKSColor.goldText)
                                    .padding(.top, 3)
                                Text(competency)
                                    .font(.subheadline)
                                    .foregroundStyle(ROCKSColor.subtleText)
                            }
                        }
                    }
                }
                OfficialLinkRow(title: "General Information", subtitle: "Official mission, vision, values, and goals", systemImage: "globe") {
                    presentedLink = IdentifiableURL(url: OfficialLinks.generalInformation)
                }
            }
            .padding(20)
        }
        .background(ROCKSColor.background)
        .navigationTitle("About ROCKS")
        .navigationBarTitleDisplayMode(.inline)
        .officialLinkSheet($presentedLink)
    }

    private func aboutCard(title: String, text: String) -> some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ExploreMenuView()
        .environment(AppState.preview)
}
