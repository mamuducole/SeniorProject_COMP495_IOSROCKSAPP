import SafariServices
import SwiftUI

// MARK: - Mentorship Home

struct MentorshipHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: MentorshipViewModel?

    var body: some View {
        Group {
            if let viewModel {
                MentorshipHomeContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ROCKSColor.background)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = MentorshipViewModel(
                    environment: appState.environment,
                    currentUserID: appState.currentUser?.id
                )
            }
        }
    }
}

private struct MentorshipHomeContent: View {
    @Environment(AppState.self) private var appState
    let viewModel: MentorshipViewModel
    @State private var champURL: IdentifiableURL?
    @State private var linkedMentor: MentorProfile?
    @State private var showMyMentorship = false
    @State private var showMentorDirectory = false

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: ROCKSTheme.spacingLG) {
                    Text("Mentorship")
                        .font(ROCKSFont.display)
                        .foregroundStyle(ROCKSColor.primaryText)

                    if viewModel.isLoading {
                        ProgressView("Loading mentorship")
                    }
                    if let error = viewModel.errorMessage {
                        ErrorStateView(message: error) { Task { await viewModel.load() } }
                    }

                    champSection

                    ctaCards

                    activeConnectionsSection
                    requestsSection
                    upcomingCheckInsSection

                    mentorPreviewSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(ROCKSColor.background)
            .navigationTitle("Mentorship")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.load() }
            .navigationDestination(item: $linkedMentor) { mentor in
                MentorProfileView(mentor: mentor, viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showMyMentorship) {
                MyMentorshipView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showMentorDirectory) {
                MentorDirectoryView(viewModel: viewModel)
            }
            .sheet(item: $champURL) { item in
                SafariSheet(url: item.url)
                    .ignoresSafeArea()
            }
        .task { await viewModel.load() }
        .onChange(of: appState.pendingDeepLink) { _, route in
            guard case .mentor(let id) = route else { return }
            appState.pendingDeepLink = nil
            Task {
                if let mentor = try? await appState.environment.mentorshipRepository.fetchMentor(id: id) {
                    linkedMentor = mentor
                }
            }
        }
    }

    /// Prominent CHAMP program card. Opens the verified CHAMP page in an in-app
    /// Safari view with a clear Done button; falls back to a safe default URL.
    private var champSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.title3)
                    .foregroundStyle(ROCKSColor.black)
                    .frame(width: 42, height: 42)
                    .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("CHAMP Mentorship Program")
                    .font(ROCKSFont.titleSmall)
                    .foregroundStyle(ROCKSColor.primaryText)
            }

            Text("CHAMP is The ROCKS, Inc. mentorship program connecting members with experienced leaders for guidance, professional development, and career growth.")
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                let url = appState.environment.configuration.champURL
                champURL = IdentifiableURL(url: url)
            } label: {
                HStack(spacing: 8) {
                    Text("Explore CHAMP")
                        .font(.headline)
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(ROCKSColor.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ROCKSColor.gold, in: Capsule())
            }
            .accessibilityLabel("Explore the CHAMP mentorship program")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient.rocksBranded.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.goldStroke, lineWidth: 1))
    }

    private var ctaCards: some View {
        VStack(alignment: .leading) {
            HStack(spacing: ROCKSTheme.spacingSM) {
                NavigationLink {
                    MentorDirectoryView(viewModel: viewModel)
                } label: {
                    mentorshipCTA(
                        title: "Find a Mentor",
                        subtitle: "Connect with experienced leaders",
                        systemImage: "person.2.fill"
                    )
                }
                .buttonStyle(.plain)
                NavigationLink {
                    BecomeMentorView(viewModel: viewModel)
                } label: {
                    mentorshipCTA(
                        title: "Become a Mentor",
                        subtitle: "Shape the next generation",
                        systemImage: "person.badge.plus"
                    )
                }
                .buttonStyle(.plain)
            }
            if viewModel.mentors.contains(where: { $0.id == viewModel.currentUserID }) {
                Button("Hide my mentor profile") {
                    Task { _ = await viewModel.hideMentorProfile() }
                }
                .font(.subheadline)
            }
        }
    }

    private func mentorshipCTA(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ROCKSColor.black)
                .frame(width: 42, height: 42)
                .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title)
                .font(.headline)
                .foregroundStyle(ROCKSColor.primaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(ROCKSColor.subtleText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.goldStroke, lineWidth: 1))
    }

    private var activeConnectionsSection: some View {
        VStack(spacing: ROCKSTheme.spacingSM) {
            ROCKSSectionHeader(title: "My Mentorship", actionTitle: "View all") {
                showMyMentorship = true
            }

            ForEach(viewModel.connections.prefix(2)) { connection in
                NavigationLink {
                    ConnectionDetailView(connection: connection, viewModel: viewModel)
                } label: {
                    ConnectionSummaryCard(connection: connection)
                }
                .buttonStyle(.plain)
            }
            if viewModel.connections.isEmpty && !viewModel.isLoading {
                Text("No active mentorships yet. Find a mentor to get started.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var requestsSection: some View {
        VStack(spacing: ROCKSTheme.spacingSM) {
            ROCKSSectionHeader(title: "Requests")

            if viewModel.requests.isEmpty && !viewModel.isLoading {
                Text("No mentorship requests yet.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(viewModel.requests) { request in
                ROCKSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        let incoming = request.mentor.id == viewModel.currentUserID
                        let person = incoming ? request.mentee : request.mentor.member
                        HStack(spacing: 12) {
                            ROCKSAvatar(name: person.fullName, url: person.avatarURL, size: .md)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(person.fullName).font(.subheadline.weight(.semibold))
                                Text(incoming ? "Incoming request" : "Outgoing request")
                                    .font(.caption).foregroundStyle(ROCKSColor.subtleText)
                            }
                            Spacer()
                            statusPill(request.status)
                        }
                        Text(request.message).font(.subheadline)
                        if request.status == .pending {
                            if incoming {
                                HStack {
                                    Button("Accept") { Task { await viewModel.respond(to: request, accept: true) } }
                                    Button("Decline") { Task { await viewModel.respond(to: request, accept: false) } }
                                }
                                .buttonStyle(.bordered)
                            } else if request.mentee.id == viewModel.currentUserID {
                                Button("Cancel request", role: .destructive) {
                                    Task { await viewModel.cancel(request) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var mentorPreviewSection: some View {
        VStack(spacing: ROCKSTheme.spacingSM) {
            ROCKSSectionHeader(title: "Featured Mentors", actionTitle: "Browse all") {
                showMentorDirectory = true
            }

            ForEach(viewModel.mentors.prefix(3)) { mentor in
                NavigationLink {
                    MentorProfileView(mentor: mentor, viewModel: viewModel)
                } label: {
                    MentorCardView(mentor: mentor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var upcomingCheckInsSection: some View {
        let upcoming = viewModel.connections.flatMap(\.checkIns)
            .filter { $0.meetingAt > .now }
            .sorted { $0.meetingAt < $1.meetingAt }
        return VStack(alignment: .leading, spacing: 8) {
            ROCKSSectionHeader(title: "Upcoming check-ins")
            if upcoming.isEmpty {
                Text("No upcoming check-ins.")
                    .font(.subheadline).foregroundStyle(ROCKSColor.subtleText)
            } else {
                ForEach(upcoming.prefix(3)) { checkIn in
                    Text(checkIn.meetingAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                }
            }
        }
    }

    private func statusPill(_ status: MentorshipRequestStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .pending: ("Pending", ROCKSColor.goldText)
            case .accepted: ("Accepted", .green)
            case .declined: ("Declined", ROCKSColor.subtleText)
            }
        }()
        return Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
    }
}

// Mentorship is always pushed with a view-destination NavigationLink. Value-based links
// (`NavigationLink(value:)`) inside it are inserted *below* view-destination screens in the
// stack, so they must not be used here; push with view destinations or state instead.

// MARK: - Shared Cards

struct MentorCardView: View {
    let mentor: MentorProfile

    var body: some View {
        ROCKSCard {
            HStack(spacing: 12) {
                ROCKSAvatar(name: mentor.member.fullName, url: mentor.member.avatarURL, size: .md)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(mentor.member.fullName)
                            .font(.headline)
                            .foregroundStyle(ROCKSColor.primaryText)
                        if mentor.isAcceptingMentees {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                                .accessibilityLabel("Accepting mentees")
                        }
                    }
                    if !mentor.member.headline.isEmpty {
                        Text(mentor.member.headline)
                            .font(.caption)
                            .foregroundStyle(ROCKSColor.subtleText)
                            .lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        ForEach(mentor.specialties.prefix(2), id: \.self) { specialty in
                            ROCKSChip(title: specialty)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ROCKSColor.goldText)
            }
        }
    }
}

struct ConnectionSummaryCard: View {
    let connection: MentorshipConnection
    @Environment(AppState.self) private var appState

    private var otherMember: MemberProfile {
        connection.mentor.id == appState.currentUser?.id ? connection.mentee : connection.mentor.member
    }

    var body: some View {
        ROCKSCard {
            HStack(spacing: 12) {
                ROCKSAvatar(name: otherMember.fullName, url: otherMember.avatarURL, size: .md)
                VStack(alignment: .leading, spacing: 6) {
                    Text(otherMember.fullName)
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.primaryText)
                    Text("Mentorship since \(connection.startedAt.formatted(.dateTime.month(.abbreviated).year()))")
                        .font(.caption)
                        .foregroundStyle(ROCKSColor.subtleText)
                    HStack(spacing: 8) {
                        ProgressView(value: connection.progress)
                            .tint(ROCKSColor.gold)
                        Text("\(connection.completedGoalCount)/\(connection.goals.count) goals")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ROCKSColor.subtleText)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ROCKSColor.goldText)
            }
        }
    }
}

// MARK: - Mentor Directory

struct MentorDirectoryView: View {
    let viewModel: MentorshipViewModel
    @State private var searchText = ""
    @State private var preferences = ""
    @State private var availableOnly = false
    @State private var selectedCareer = ""
    @State private var selectedBackground = ""
    @State private var selectedChapter = ""

    private var filteredMentors: [MentorProfile] {
        return viewModel.mentors.filter { mentor in
            MentorshipViewModel.matches(
                mentor, search: searchText, availableOnly: availableOnly,
                career: selectedCareer, background: selectedBackground, chapter: selectedChapter
            )
        }
    }

    private var suggested: [MentorProfile] {
        filteredMentors.filter { !MentorshipViewModel.matchReasons(for: $0, preferences: preferences).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ROCKSTheme.spacingMD) {
                ROCKSSearchField(prompt: "Search mentors", text: $searchText)
                TextField("Your interests or goals, separated by commas", text: $preferences)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Your mentorship interests or goals")
                Text("Preferences are used only while browsing. Suggestions are not confirmed relationships.")
                    .font(.caption).foregroundStyle(ROCKSColor.subtleText)
                Toggle("Accepting mentees only", isOn: $availableOnly)
                filter("Career field", selection: $selectedCareer, values: viewModel.mentors.compactMap(\.careerField))
                filter("Background", selection: $selectedBackground, values: viewModel.mentors.compactMap(\.careerBackground))
                filter("Chapter", selection: $selectedChapter, values: viewModel.mentors.compactMap(\.member.chapterName))

                if !suggested.isEmpty {
                    Text("Suggested mentors").font(.headline)
                    ForEach(suggested) { mentor in
                        NavigationLink {
                    MentorProfileView(mentor: mentor, viewModel: viewModel)
                } label: {
                            VStack(alignment: .leading) {
                                MentorCardView(mentor: mentor)
                                Text("Shared interests: \(MentorshipViewModel.matchReasons(for: mentor, preferences: preferences).joined(separator: ", "))")
                                    .font(.caption).foregroundStyle(ROCKSColor.subtleText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("All mentors").font(.headline)

                if filteredMentors.isEmpty {
                    EmptyStateView(title: "No mentors found", systemImage: "person.2", message: "Try a different name or specialty.")
                        .frame(minHeight: 220)
                } else {
                    LazyVStack(spacing: ROCKSTheme.spacingSM) {
                        ForEach(filteredMentors) { mentor in
                            NavigationLink {
                    MentorProfileView(mentor: mentor, viewModel: viewModel)
                } label: {
                                MentorCardView(mentor: mentor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Find a Mentor")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filter(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        Picker(title, selection: selection) {
            Text("All \(title.lowercased())").tag("")
            ForEach(Array(Set(values.filter { !$0.isEmpty })).sorted(), id: \.self) { value in
                Text(value).tag(value)
            }
        }
        .tint(ROCKSColor.goldText)
    }
}

// MARK: - Mentor Profile

struct MentorProfileView: View {
    let mentor: MentorProfile
    let viewModel: MentorshipViewModel
    @Environment(AppState.self) private var appState
    @State private var showingRequestSheet = false
    @State private var requestSent = false

    private var requestUnavailable: Bool {
        mentor.id == appState.currentUser?.id
            || viewModel.requests.contains { $0.mentor.id == mentor.id && $0.status == .pending }
            || viewModel.connections.contains { $0.mentor.id == mentor.id && $0.mentee.id == appState.currentUser?.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ROCKSTheme.spacingMD) {
                HStack(spacing: 16) {
                    ROCKSAvatar(name: mentor.member.fullName, url: mentor.member.avatarURL, size: .lg)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mentor.member.fullName)
                            .font(ROCKSFont.titleSmall)
                            .foregroundStyle(ROCKSColor.primaryText)
                        if !mentor.member.headline.isEmpty {
                            Text(mentor.member.headline)
                                .font(.subheadline)
                                .foregroundStyle(ROCKSColor.subtleText)
                        }
                        Text(mentor.isAcceptingMentees ? "Accepting mentees" : "Not accepting mentees")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(mentor.isAcceptingMentees ? .green : ROCKSColor.subtleText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background((mentor.isAcceptingMentees ? Color.green : ROCKSColor.subtleText).opacity(0.14), in: Capsule())
                    }
                }

                if let bio = mentor.mentoringBio, !bio.isEmpty {
                    ROCKSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mentorship Focus")
                                .font(.headline)
                                .foregroundStyle(ROCKSColor.primaryText)
                            Text(bio)
                                .font(.body)
                                .foregroundStyle(ROCKSColor.subtleText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                ROCKSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Specialties")
                            .font(.headline)
                            .foregroundStyle(ROCKSColor.primaryText)
                        FlowLayout(spacing: 8) {
                            ForEach(mentor.specialties, id: \.self) { specialty in
                                ROCKSChip(title: specialty)
                            }
                            if let careerField = mentor.careerField, !careerField.isEmpty {
                                Text("Career field: \(careerField)")
                            }
                            if let background = mentor.careerBackground, !background.isEmpty {
                                Text("Background: \(background)")
                            }
                            if !mentor.interests.isEmpty {
                                Text("Interests: \(mentor.interests.joined(separator: ", "))")
                            }
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    showingRequestSheet = true
                } label: {
                    Label(requestSent ? "Request Sent" : "Request Mentorship", systemImage: requestSent ? "checkmark.circle.fill" : "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(ROCKSColor.gold)
                .foregroundStyle(ROCKSColor.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(!mentor.isAcceptingMentees || requestSent || requestUnavailable)
                .opacity(mentor.isAcceptingMentees ? 1 : 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Mentor")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRequestSheet) {
            MentorshipRequestSheet(mentor: mentor, viewModel: viewModel) {
                requestSent = true
            }
            .presentationDetents([.medium])
        }
    }
}

private struct MentorshipRequestSheet: View {
    let mentor: MentorProfile
    let viewModel: MentorshipViewModel
    let onSent: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ROCKSTheme.spacingMD) {
                Text("Introduce yourself and share what you'd like to work on with \(mentor.member.firstName).")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)

                TextEditor(text: $message)
                    .frame(minHeight: 120)
                    .padding(10)
                    .background(ROCKSColor.insetBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .tint(ROCKSColor.goldText)

                Button {
                    Task {
                        if await viewModel.sendRequest(to: mentor, message: message) {
                            onSent()
                            dismiss()
                        }
                    }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 50)
                    } else {
                        Text("Send Request")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ROCKSColor.gold)
                .foregroundStyle(ROCKSColor.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.count > 1000 || viewModel.isSending)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(20)
            .background(ROCKSColor.background)
            .navigationTitle("Request Mentorship")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Become a Mentor

struct BecomeMentorView: View {
    let viewModel: MentorshipViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var specialtyDraft = ""
    @State private var specialties: [String] = []
    @State private var bio = ""
    @State private var careerField = ""
    @State private var careerBackground = ""
    @State private var interests = ""
    @State private var sharesChapter = false
    @State private var isAccepting = true
    @State private var consentsToDirectory = false
    @State private var isSaving = false
    @State private var isReviewing = false
    @State private var didPrefill = false

    /// The member's current directory profile, if one is visible. Saving always upserts the
    /// single row keyed by the member's ID, so editing never creates a duplicate.
    private var existingProfile: MentorProfile? {
        viewModel.mentors.first { $0.id == viewModel.currentUserID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ROCKSTheme.spacingMD) {
                Text(existingProfile == nil
                    ? "Share your experience with the next generation of ROCKS leaders. Add the areas you can mentor in."
                    : "Update your mentor profile. Changes appear in the mentor directory after you save.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)

                ROCKSCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Before you start").font(.headline)
                        Label("Available to approved ROCKS Connect members", systemImage: "checkmark.seal")
                        Label("Add at least one mentorship specialty", systemImage: "list.bullet")
                        Label("Agree to share your profile in the mentor directory", systemImage: "eye")
                        Text("Listing yourself in the app directory is not CHAMP enrollment or an official ROCKS endorsement.")
                            .font(.caption)
                            .foregroundStyle(ROCKSColor.subtleText)
                    }
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.primaryText)
                }

                ROCKSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Specialties")
                            .font(.headline)
                            .foregroundStyle(ROCKSColor.primaryText)
                        HStack {
                            TextField("e.g. Leadership, Career Transition", text: $specialtyDraft)
                                .font(.subheadline)
                                .tint(ROCKSColor.goldText)
                            Button("Add") { addSpecialty() }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ROCKSColor.goldText)
                                .disabled(specialtyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if !specialties.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(specialties, id: \.self) { specialty in
                                    ROCKSChip(title: specialty)
                                        .onTapGesture {
                                            specialties.removeAll { $0 == specialty }
                                        }
                                }
                            }
                        }
                    }
                }

                ROCKSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mentorship Bio")
                            .font(.headline)
                            .foregroundStyle(ROCKSColor.primaryText)
                        TextEditor(text: $bio)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(ROCKSColor.insetBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .tint(ROCKSColor.goldText)
                    }
                }

                ROCKSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Optional professional details").font(.headline)
                        TextField("Career field", text: $careerField)
                        TextField("Military or civilian background", text: $careerBackground)
                        TextField("Leadership interests, separated by commas", text: $interests)
                        Toggle("Share my chapter", isOn: $sharesChapter)
                        Toggle("Accepting mentorship requests", isOn: $isAccepting)
                    }
                }
                Toggle(
                    "I agree to share my name, photo, rank and the details entered here with signed-in members in the mentor directory.",
                    isOn: $consentsToDirectory
                )
                .font(.subheadline)
                Text("You can hide your profile from the mentorship dashboard.")
                    .font(.caption).foregroundStyle(ROCKSColor.subtleText)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    isReviewing = true
                } label: {
                    Group {
                        if isSaving { ProgressView() } else { Text(existingProfile == nil ? "Review & Join as a Mentor" : "Review & Save Changes") }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(ROCKSColor.gold)
                .foregroundStyle(ROCKSColor.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(specialties.isEmpty || !consentsToDirectory || isSaving)
                .opacity(specialties.isEmpty || !consentsToDirectory ? 0.5 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle(existingProfile == nil ? "Become a Mentor" : "Edit Mentor Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: prefill)
        .confirmationDialog(
            existingProfile == nil ? "Publish your mentor profile?" : "Save your mentor profile?",
            isPresented: $isReviewing,
            titleVisibility: .visible
        ) {
            Button(existingProfile == nil ? "Join as a Mentor" : "Save Changes") { save() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text(reviewSummary)
        }
    }

    private var settings: MentorDirectorySettings {
        MentorDirectorySettings(
            specialties: specialties,
            bio: bio,
            careerField: careerField,
            careerBackground: careerBackground,
            interests: interests.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            sharesChapter: sharesChapter,
            isAccepting: isAccepting
        )
    }

    private var reviewSummary: String {
        var lines = ["Specialties: \(specialties.joined(separator: ", "))"]
        if !careerField.isEmpty { lines.append("Career field: \(careerField)") }
        lines.append(isAccepting ? "Accepting mentorship requests" : "Not accepting requests right now")
        lines.append(sharesChapter ? "Chapter shared in the directory" : "Chapter not shared")
        lines.append("Signed-in members will see this profile in the mentor directory.")
        return lines.joined(separator: "\n")
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        guard let profile = existingProfile else { return }
        specialties = profile.specialties
        bio = profile.mentoringBio ?? ""
        careerField = profile.careerField ?? ""
        careerBackground = profile.careerBackground ?? ""
        interests = profile.interests.joined(separator: ", ")
        sharesChapter = profile.sharesChapter
        isAccepting = profile.isAcceptingMentees
        consentsToDirectory = true
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            let saved = await viewModel.becomeMentor(settings: settings)
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func addSpecialty() {
        let value = specialtyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !specialties.contains(value) else { return }
        specialties.append(value)
        specialtyDraft = ""
    }
}

// MARK: - My Mentorship

struct MyMentorshipView: View {
    let viewModel: MentorshipViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: ROCKSTheme.spacingSM) {
                if viewModel.connections.isEmpty {
                    EmptyStateView(
                        title: "No active mentorships",
                        systemImage: "person.2",
                        message: "Find a mentor to start a mentorship relationship."
                    )
                    .frame(minHeight: 260)
                } else {
                    ForEach(viewModel.connections) { connection in
                        NavigationLink {
                    ConnectionDetailView(connection: connection, viewModel: viewModel)
                } label: {
                            ConnectionSummaryCard(connection: connection)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("My Mentorship")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Connection Detail (goals + check-ins)

struct ConnectionDetailView: View {
    let connection: MentorshipConnection
    let viewModel: MentorshipViewModel
    @State private var showingAddGoal = false
    @State private var showingAddCheckIn = false
    @State private var newGoalTitle = ""
    @State private var newGoalMilestones = ""
    @State private var newCheckInNote = ""
    @State private var newCheckInNextSteps = ""
    @State private var newCheckInDate = Date.now
    @State private var confirmEnd = false
    @Environment(\.dismiss) private var dismiss

    private var liveConnection: MentorshipConnection {
        viewModel.connections.first { $0.id == connection.id } ?? connection
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ROCKSTheme.spacingMD) {
                ConnectionSummaryCard(connection: liveConnection)

                goalsSection
                checkInsSection
                if let error = viewModel.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                Button("End mentorship", role: .destructive) { confirmEnd = true }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Mentorship")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("End this mentorship?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End mentorship", role: .destructive) {
                Task {
                    if await viewModel.end(connection) { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var goalsSection: some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Goals")
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.primaryText)
                    Spacer()
                    Button {
                        showingAddGoal.toggle()
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ROCKSColor.goldText)
                    }
                }

                if showingAddGoal {
                    VStack {
                        TextField("Goal title", text: $newGoalTitle)
                            .font(.subheadline)
                            .tint(ROCKSColor.goldText)
                        TextField("Milestones, separated by commas", text: $newGoalMilestones)
                            .font(.subheadline)
                        Button("Save") {
                            Task {
                                let milestones = newGoalMilestones.split(separator: ",")
                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                if await viewModel.addGoal(newGoalTitle, milestones: milestones, to: connection) {
                                    newGoalTitle = ""
                                    newGoalMilestones = ""
                                    showingAddGoal = false
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.goldText)
                        .disabled(newGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if liveConnection.goals.isEmpty && !showingAddGoal {
                    Text("No goals yet — set one together.")
                        .font(.subheadline)
                        .foregroundStyle(ROCKSColor.subtleText)
                }

                ForEach(liveConnection.goals) { goal in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(goal.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Menu("\(goal.progressPercent)%") {
                                ForEach([0, 25, 50, 75, 100], id: \.self) { percent in
                                    Button("\(percent)%") {
                                        Task { await viewModel.updateProgress(goal, percent: percent, in: connection) }
                                    }
                                }
                            }
                        }
                        ProgressView(value: Double(goal.progressPercent), total: 100).tint(ROCKSColor.gold)
                        ForEach(goal.milestones.indices, id: \.self) { index in
                            Text("• \(goal.milestones[index])").font(.caption)
                        }
                        ForEach(goal.history) { record in
                            Text("\(record.recordedAt.formatted(date: .abbreviated, time: .shortened)): \(record.percent)%")
                                .font(.caption).foregroundStyle(ROCKSColor.subtleText)
                        }
                    }
                }
            }
        }
    }

    private var checkInsSection: some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Check-Ins")
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.primaryText)
                    Spacer()
                    Button {
                        showingAddCheckIn.toggle()
                    } label: {
                        Label("Log", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ROCKSColor.goldText)
                    }
                }

                if showingAddCheckIn {
                    VStack(spacing: 10) {
                        DatePicker("Date and time", selection: $newCheckInDate, displayedComponents: [.date, .hourAndMinute])
                            .font(.subheadline)
                            .tint(ROCKSColor.goldText)
                        TextField("What did you cover?", text: $newCheckInNote)
                            .font(.subheadline)
                            .tint(ROCKSColor.goldText)
                        TextField("Next steps (optional)", text: $newCheckInNextSteps)
                            .font(.subheadline)
                        Button("Save Check-In") {
                            Task {
                                let nextSteps = newCheckInNextSteps.trimmingCharacters(in: .whitespacesAndNewlines)
                                if await viewModel.addCheckIn(
                                    note: newCheckInNote, meetingAt: newCheckInDate,
                                    nextSteps: nextSteps.isEmpty ? nil : nextSteps, to: connection
                                ) {
                                    newCheckInNote = ""
                                    newCheckInNextSteps = ""
                                    showingAddCheckIn = false
                                }
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.goldText)
                        .disabled(newCheckInNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if liveConnection.checkIns.isEmpty && !showingAddCheckIn {
                    Text("Log your first check-in after your next session.")
                        .font(.subheadline)
                        .foregroundStyle(ROCKSColor.subtleText)
                }

                ForEach(liveConnection.checkIns) { checkIn in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(ROCKSColor.gold)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(checkIn.meetingAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ROCKSColor.goldText)
                            Text(checkIn.note)
                                .font(.subheadline)
                                .foregroundStyle(ROCKSColor.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            if let nextSteps = checkIn.nextSteps, !nextSteps.isEmpty {
                                Text("Next steps: \(nextSteps)").font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout (chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    MentorshipHomeView()
        .environment(AppState.preview)
}

// MARK: - Safari helpers

/// In-app Safari browser with a clear Done button so users can return to the app.
struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
