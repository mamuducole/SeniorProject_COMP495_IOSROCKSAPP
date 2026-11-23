import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var presentedLink: IdentifiableURL?
    @State private var confirmDeletion = false
    @State private var isDeleting = false
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard
                    quoteBlock
                    actionsGrid
                    membershipSection
                    upcomingEventsSection
                    mentorshipSection
                    accountList
                }
                .padding(20)
            }
            .background(ROCKSColor.background)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .officialLinkSheet($presentedLink)
            .confirmationDialog("Delete your account?", isPresented: $confirmDeletion, titleVisibility: .visible) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        isDeleting = true
                        deletionError = await appState.deleteAccount()
                        isDeleting = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your ROCKS Connect account, profile, posts, comments, and mentorship records. This cannot be undone. Your membership with The ROCKS, Inc. is managed separately.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [ROCKSColor.black, ROCKSColor.charcoal], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(alignment: .leading, spacing: 18) {
                Image("rocksLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 56)
                    .accessibilityLabel("The ROCKS, Inc. emblem")
                HStack(alignment: .center, spacing: 14) {
                    ROCKSAvatar(
                        name: appState.currentMember?.fullName ?? "ROCKS Member",
                        url: appState.currentMember?.avatarURL,
                        size: .lg
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.currentMember?.fullName ?? "ROCKS Member")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        if let chapter = appState.currentMember?.chapterName, !chapter.isEmpty {
                            Text(chapter)
                                .font(.subheadline)
                                .foregroundStyle(ROCKSColor.onDarkText.opacity(0.85))
                        }
                        if let role = appState.currentUser?.role {
                            Text("Account role: \(role.displayName)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ROCKSColor.goldLight)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        }
    }

    private var quoteBlock: some View {
        VStack(spacing: 8) {
            Text("“Men of Service. Leaders for Life.”")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(ROCKSColor.primaryText)
                .multilineTextAlignment(.center)
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(ROCKSColor.gold.opacity(0.7))
        }
        .padding(.vertical, 4)
    }

    private var actionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            navActionCard(title: "My Events", systemImage: "calendar", destination: EventListView(isEmbedded: true))
            navActionCard(title: "Mentorship", systemImage: "person.2.fill", destination: MentorshipHomeView())
            navActionCard(title: "Scholarships", systemImage: "graduationcap.fill", destination: ScholarshipInfoView())
            navActionCard(title: "Saved Publications", systemImage: "bookmark", destination: NewsView(showsSavedFirst: true))
        }
    }

    /// Membership renewal and CHAMP access through the official ROCKS systems.
    private var membershipSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Membership")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Spacer()
                NavigationLink(destination: MembershipView()) {
                    Text("Details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.goldText)
                        .frame(minHeight: 44)
                }
            }

            if let summary = MembershipAccessSummary(user: appState.currentUser, member: appState.currentMember) {
                MembershipAccessCard(summary: summary)
            }

            Button {
                presentedLink = IdentifiableURL(url: OfficialLinks.memberLogin)
            } label: {
                Label("Renew Membership", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(ROCKSColor.black)
                    .background(ROCKSColor.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(appState.isDemoUser)
            .accessibilityHint(appState.isDemoUser ? "Unavailable in demo mode" : "Opens the official member login where renewal is completed")

            if appState.isDemoUser {
                Text("Membership renewal is disabled in demo mode.")
                    .font(.caption)
                    .foregroundStyle(ROCKSColor.subtleText)
            }

            OfficialLinkRow(title: "CHAMP Mentorship Platform", subtitle: "Become a mentor or find a mentor after signing in", systemImage: "person.2.fill") {
                presentedLink = IdentifiableURL(url: OfficialLinks.mentorship)
            }

            Text("Renewal and payment are handled securely on the official ROCKS website. The app never stores passwords or payment details.")
                .font(.caption)
                .foregroundStyle(ROCKSColor.subtleText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var upcomingEventsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Upcoming Events")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Spacer()
                NavigationLink(destination: EventListView(isEmbedded: true)) {
                    Text("See All")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.goldText)
                }
            }

            Text("View the official calendar and set personal reminders.")
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Mentorship connections live on the official CHAMP platform; the app
    /// links there instead of showing sample contacts.
    private var mentorshipSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("My Mentorship")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Spacer()
            }

            NavigationLink(destination: CHAMPMentorshipView()) {
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(ROCKSColor.gold.opacity(0.20))
                        .frame(width: 44, height: 44)
                        .overlay(Image(systemName: "person.2.fill").foregroundStyle(ROCKSColor.goldText))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CHAMP Mentorship")
                            .font(.headline)
                            .foregroundStyle(ROCKSColor.primaryText)
                        Text("Your mentor connections are managed on the official CHAMP platform.")
                            .font(.subheadline)
                            .foregroundStyle(ROCKSColor.subtleText)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(ROCKSColor.goldText)
                        .accessibilityHidden(true)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 8) {
                navProfileRow(title: "Edit Profile", systemImage: "person.crop.circle", destination: EditProfileView())
                navProfileRow(title: "My Events", systemImage: "calendar", destination: EventListView(isEmbedded: true))
                navProfileRow(title: "Mentorship", systemImage: "person.2", destination: CHAMPMentorshipView())
                navProfileRow(title: "Scholarships", systemImage: "graduationcap.fill", destination: ScholarshipInfoView())
                navProfileRow(title: "Membership", systemImage: "shield.fill", destination: MembershipView())
                navProfileRow(title: "Member Directory", systemImage: "person.3.fill", destination: MemberDirectoryView())
                navProfileRow(title: "Community Board", systemImage: "bubble.left.and.bubble.right", destination: CommunityView())
                navProfileRow(title: "Notifications", systemImage: "bell", destination: NotificationsView())
                if appState.environment.isLive,
                   appState.currentUser?.role.can(.manageChapterContent) == true {
                    navProfileRow(title: "Admin Dashboard", systemImage: "lock.shield", destination: AdminDashboardView())
                }
                linkProfileRow(title: "Donate", systemImage: "heart.fill", url: OfficialLinks.donate)
                    .disabled(appState.isDemoUser)
                linkProfileRow(title: "About The ROCKS", systemImage: "info.circle", url: OfficialLinks.about)
                linkProfileRow(title: "Help & Contact", systemImage: "questionmark.circle", url: OfficialLinks.contact)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))

            Button(role: .destructive) {
                Task { await appState.signOut() }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if !appState.isDemoUser {
                Button(role: .destructive) {
                    confirmDeletion = true
                } label: {
                    Group {
                        if isDeleting { ProgressView() } else { Text("Delete Account").font(.subheadline) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .disabled(isDeleting)
                if let deletionError {
                    Text(deletionError)
                        .font(.footnote)
                        .foregroundStyle(ROCKSColor.badgeRed)
                }
            }
        }
    }

    private func navProfileRow<Destination: View>(title: String, systemImage: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            profileRowLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func linkProfileRow(title: String, systemImage: String, url: URL) -> some View {
        Button {
            presentedLink = IdentifiableURL(url: url)
        } label: {
            profileRowLabel(title: title, systemImage: systemImage, isExternal: true)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the official ROCKS website")
    }

    private func profileRowLabel(title: String, systemImage: String, isExternal: Bool = false) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(ROCKSColor.goldText)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.primaryText)
            Spacer()
            Image(systemName: isExternal ? "arrow.up.right.square" : "chevron.right")
                .font(.caption)
                .foregroundStyle(ROCKSColor.subtleText)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func navActionCard<Destination: View>(title: String, systemImage: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(ROCKSColor.goldText)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(minHeight: 88)
            .frame(maxWidth: .infinity)
            .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Edits the member-owned profile fields. Role, chapter, email, and membership are changed only by administrators.
struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var rankTitle = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    var body: some View {
        Form {
            Section("Name") {
                TextField("First name", text: $firstName).textContentType(.givenName)
                TextField("Last name", text: $lastName).textContentType(.familyName)
            }
            Section("Professional") {
                TextField("Rank or title", text: $rankTitle)
                TextField("Biography", text: $bio, axis: .vertical)
                    .lineLimit(3...8)
            }
            Section {
                LabeledContent("Email", value: appState.currentUser?.email ?? "")
                LabeledContent("Chapter", value: appState.currentMember?.chapterName ?? "Not assigned")
            } footer: {
                Text("Your email, chapter, and membership are managed by ROCKS administrators. Your biography and chapter are visible only to you.")
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
            Button {
                Task { await save() }
            } label: {
                if isSaving { ProgressView() } else { Text("Save") }
            }
            .disabled(isSaving)
        }
        .navigationTitle("Edit Profile")
        .onAppear {
            guard !didLoad, let member = appState.currentMember else { return }
            didLoad = true
            firstName = member.firstName
            lastName = member.lastName
            rankTitle = member.rankTitle ?? ""
            bio = member.bio ?? ""
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = await appState.updateProfile(
            ProfileUpdate(firstName: firstName, lastName: lastName, rankTitle: rankTitle, bio: bio)
        )
        if errorMessage == nil { dismiss() }
    }
}
