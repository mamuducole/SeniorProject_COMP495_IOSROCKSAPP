import SwiftUI

/// Searchable chapter directory based on the chapters and interest groups
/// published on the official ROCKS, Inc. chapter finder. The former map view
/// was removed in favor of this list-first directory.
struct ChapterListView: View {
    @State private var searchText = ""
    @State private var presentedLink: IdentifiableURL?
    private let chapters = Chapter.examples

    private var filteredChapters: [Chapter] {
        chapters.filter { $0.matches(searchText: searchText) }
    }

    private var activeChapters: [Chapter] {
        filteredChapters.filter { !$0.isInterestGroup }
    }

    private var interestGroups: [Chapter] {
        filteredChapters.filter(\.isInterestGroup)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if filteredChapters.isEmpty {
                        EmptyStateView(
                            title: "No matches",
                            systemImage: "magnifyingglass",
                            message: "No chapter or interest group matches “\(searchText)”. Try a different name, city, state, or installation."
                        )
                        .frame(minHeight: 220)
                    } else {
                        if !activeChapters.isEmpty {
                            directorySection(title: "Chapters", chapters: activeChapters)
                        }
                        if !interestGroups.isEmpty {
                            directorySection(title: "Interest Groups", chapters: interestGroups)
                        }
                    }

                    OfficialLinkRow(title: "Official Chapter Finder", subtitle: "Interactive map and chapter contacts on rocksinc.org", systemImage: "globe") {
                        presentedLink = IdentifiableURL(url: OfficialLinks.chapterFinder)
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Chapters")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Chapter.self) { chapter in
            ChapterDetailView(chapter: chapter)
        }
        .officialLinkSheet($presentedLink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chapters")
                .font(.system(size: 42, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            Text("Find a chapter near you and connect with a network of leaders.")
                .font(.body)
                .foregroundStyle(ROCKSColor.onDarkText.opacity(0.9))
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ROCKSColor.onDarkText.opacity(0.8))
                    .accessibilityHidden(true)
                TextField("Search by city, state, installation, or chapter name", text: $searchText)
                    .font(.subheadline)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Search chapters")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ROCKSColor.onDarkText.opacity(0.7))
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [ROCKSColor.black, ROCKSColor.charcoal], startPoint: .top, endPoint: .bottom))
    }

    private func directorySection(title: String, chapters: [Chapter]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Spacer()
                Text("\(chapters.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ROCKSColor.goldText)
                    .accessibilityLabel("\(chapters.count) \(title)")
            }

            VStack(spacing: 10) {
                ForEach(chapters) { chapter in
                    NavigationLink(value: chapter) {
                        chapterRow(chapter)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(ROCKSColor.gold.opacity(0.16))
                    .frame(width: 48, height: 48)
                Image(systemName: chapter.isInterestGroup ? "person.3" : "building.columns")
                    .font(.body)
                    .foregroundStyle(ROCKSColor.goldText)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.name)
                    .font(.headline)
                    .foregroundStyle(ROCKSColor.primaryText)
                    .multilineTextAlignment(.leading)
                Text(chapter.locationLabel)
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                if let installation = chapter.installation {
                    Text(installation)
                        .font(.caption)
                        .foregroundStyle(ROCKSColor.goldText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(ROCKSColor.goldText)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
    }
}

struct ChapterDetailView: View {
    let chapter: Chapter
    @Environment(AppState.self) private var appState
    @State private var presentedLink: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [ROCKSColor.black, ROCKSColor.charcoal], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 200)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(chapter.isInterestGroup ? "INTEREST GROUP" : "CHAPTER")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(ROCKSColor.goldLight)
                        Text(chapter.name)
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        Text(chapter.locationLabel)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(20)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                ROCKSCard {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("About")
                        Text(chapter.description)
                            .font(.subheadline)
                            .foregroundStyle(ROCKSColor.subtleText)

                        detailRow(icon: "mappin.and.ellipse", title: chapter.locationLabel)
                        if let installation = chapter.installation {
                            detailRow(icon: "building.columns", title: installation)
                        }
                        if let contactPerson = chapter.contactPerson {
                            detailRow(icon: "person.fill", title: contactPerson)
                        }
                        if let email = chapter.email {
                            detailRow(icon: "envelope.fill", title: email)
                        }
                    }
                }

                if let website = chapter.website {
                    OfficialLinkRow(title: "Chapter Website", subtitle: website.absoluteString, systemImage: "globe") {
                        presentedLink = IdentifiableURL(url: website)
                    }
                }

                VStack(spacing: 10) {
                    OfficialLinkRow(title: "Official Chapter Finder", subtitle: "Chapter contacts and details on rocksinc.org", systemImage: "globe") {
                        presentedLink = IdentifiableURL(url: OfficialLinks.chapterFinder)
                    }
                    OfficialLinkRow(title: "Become a Member", subtitle: "Join The ROCKS through the official site", systemImage: "person.badge.plus") {
                        presentedLink = IdentifiableURL(url: OfficialLinks.joinMembership)
                    }
                    .disabled(appState.isDemoUser)
                    .accessibilityHint(appState.isDemoUser ? "Unavailable in demo mode" : "Opens the official membership sign-up")
                }

                Text("Chapter leadership and contact details are maintained on the official ROCKS chapter finder.")
                    .font(.caption)
                    .foregroundStyle(ROCKSColor.subtleText)
            }
            .padding(20)
            .padding(.bottom, 10)
        }
        .background(ROCKSColor.background)
        .navigationTitle(chapter.isInterestGroup ? "Interest Group" : "Chapter")
        .navigationBarTitleDisplayMode(.inline)
        .officialLinkSheet($presentedLink)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(ROCKSColor.primaryText)
    }

    private func detailRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(ROCKSColor.goldText)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.primaryText)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ChapterListView()
}
