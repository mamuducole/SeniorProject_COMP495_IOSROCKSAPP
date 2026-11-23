import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var feed: FeedViewModel?
    @State private var selectedPostID: UUID?
    @State private var calendar = OfficialCalendarStore.shared
    @State private var featuredPublication: Publication?
    @State private var publicationError: String?

    private var canParticipate: Bool {
        appState.currentUser?.role.can(.participateInCommunity) ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    greeting
                    mentorHero
                    quickActions
                    communitySection
                    eventsSection
                    publicationSection
                    missionSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(ROCKSColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedPostID) { id in
                if let feed {
                    PostDetailView(postID: id, viewModel: feed, canParticipate: canParticipate)
                }
            }
            .refreshable {
                await feed?.load()
                await calendar.load()
                loadPublications()
            }
            .task {
                if feed == nil {
                    feed = FeedViewModel(environment: appState.environment, currentUserID: appState.currentUser?.id, isModerator: appState.currentUser?.role == .nationalAdmin)
                }
                await feed?.load()
                await calendar.load()
                loadPublications()
            }
            .onAppear {
                if let feed, feed.hasLoaded {
                    Task { await feed.load() }
                }
            }
            .alert("Community", isPresented: Binding(
                get: { feed?.actionErrorMessage != nil && selectedPostID == nil },
                set: { if !$0 { feed?.actionErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { feed?.actionErrorMessage = nil }
            } message: {
                Text(feed?.actionErrorMessage ?? "")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("rocksLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 52)
                .accessibilityLabel("The ROCKS, Inc. emblem")
            VStack(alignment: .leading, spacing: 1) {
                Text("ROCKS")
                    .font(.headline.weight(.bold))
                Text("CONNECT")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(ROCKSColor.goldText)
            }
            Spacer()
            NavigationLink(destination: NotificationsView()) {
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundStyle(ROCKSColor.primaryText)
                    .frame(width: 44, height: 44)
                    .background(ROCKSColor.cardBackground, in: Circle())
            }
            .accessibilityLabel("Notifications")
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Good to see you, \(appState.currentMember?.firstName ?? "member").")
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
            Text("Your people.\nYour potential.")
                .font(ROCKSFont.display)
                .foregroundStyle(ROCKSColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var mentorHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ROOTED IN SERVICE")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(ROCKSColor.goldLight)
            Text("Great leaders grow together.")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text("Find guidance and build meaningful connections.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            NavigationLink(destination: MentorshipHomeView()) {
                Text("Find a Mentor")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ROCKSColor.black)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(ROCKSColor.goldLight, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(ROCKSPressStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 270, alignment: .bottomLeading)
        .background {
            GeometryReader { geometry in
                Image("rocksHomeMentorship")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.84)], startPoint: .top, endPoint: .bottom))
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: CommunityView()) {
                ROCKSQuickActionTile(title: "Community", systemImage: "bubble.left.and.bubble.right")
            }
            Button { appState.selectedTab = .events } label: {
                ROCKSQuickActionTile(title: "Events", systemImage: "calendar")
            }
            NavigationLink(destination: ChapterListView()) {
                ROCKSQuickActionTile(title: "Chapters", systemImage: "mappin.and.ellipse")
            }
        }
        .buttonStyle(ROCKSPressStyle())
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Community")
                    .font(.title2.weight(.bold))
                Spacer()
                NavigationLink("See all", destination: CommunityView())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ROCKSColor.goldText)
            }
            if let feed {
                if !feed.hasLoaded && feed.isLoading {
                    ProgressView("Loading community")
                        .frame(maxWidth: .infinity, minHeight: 90)
                } else if let error = feed.loadErrorMessage, feed.posts.isEmpty {
                    ErrorStateView(message: error) { Task { await feed.load() } }
                } else if feed.posts.isEmpty {
                    Text("Community updates will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(ROCKSColor.subtleText)
                } else {
                    if let error = feed.loadErrorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(ROCKSColor.badgeRed)
                    }
                    ForEach(Array(feed.posts.prefix(2))) { post in
                        PostCardView(
                            post: post,
                            currentUserID: feed.currentUserID,
                            isLikeInFlight: feed.likesInFlight.contains(post.id),
                            canInteract: canParticipate,
                            bodyLineLimit: 5,
                            onLike: { Task { await feed.toggleLike(for: post) } },
                            onComment: { selectedPostID = post.id },
                            onOpen: { selectedPostID = post.id }
                        )
                    }
                }
            } else {
                ProgressView("Loading community")
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Events").font(.title2.weight(.bold))
                Spacer()
                Button("See all") { appState.selectedTab = .events }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ROCKSColor.goldText)
            }
            if calendar.isLoading {
                ProgressView("Loading events")
            } else if let error = calendar.errorMessage {
                Text(error).font(.footnote).foregroundStyle(ROCKSColor.badgeRed)
            } else if calendar.events(in: .upcoming).isEmpty {
                Text("No upcoming events are currently available.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
            } else {
                ForEach(Array(calendar.events(in: .upcoming).prefix(2))) { event in
                    NavigationLink(destination: OfficialEventDetailView(event: event, store: calendar)) {
                        ROCKSCard {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.title2)
                                    .foregroundStyle(ROCKSColor.goldText)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title).font(.headline).foregroundStyle(ROCKSColor.primaryText)
                                    Text(event.dateLabel).font(.subheadline).foregroundStyle(ROCKSColor.subtleText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(ROCKSColor.subtleText)
                            }
                        }
                    }
                    .buttonStyle(ROCKSPressStyle())
                }
            }
        }
    }

    private var publicationSection: some View {
        NavigationLink(destination: NewsView()) {
            ROCKSCard {
                HStack(spacing: 14) {
                    Image(systemName: "book.closed")
                        .font(.title2)
                        .foregroundStyle(ROCKSColor.goldText)
                        .frame(width: 52, height: 52)
                        .background(ROCKSColor.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ROCKS REFRESH").font(.caption.weight(.bold)).foregroundStyle(ROCKSColor.goldText)
                        Text(featuredPublication?.title ?? "News & Publications")
                            .font(.headline).foregroundStyle(ROCKSColor.primaryText)
                        Text(publicationError ?? (featuredPublication == nil ? "Explore the publication library." : "Open the publication library."))
                            .font(.subheadline).foregroundStyle(ROCKSColor.subtleText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(ROCKSColor.subtleText)
                }
            }
        }
        .buttonStyle(ROCKSPressStyle())
    }

    private var missionSection: some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Our Mission").font(.headline)
                Text("Strengthen military officers and civilians by providing and promoting mentorship, professional leader development, scholarship and networking.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
            }
        }
    }

    private func loadPublications() {
        do {
            featuredPublication = try PublicationRepository().fetchPublications().first(where: \.isRefresh)
            publicationError = nil
        } catch {
            publicationError = (error as? LocalizedError)?.errorDescription ?? "Unable to load publications."
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState.preview)
}
