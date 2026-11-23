import SwiftUI

/// Curated member resources — news, brand materials, and organizational references.
struct ResourcesView: View {
    @Environment(AppState.self) private var appState
    @State private var presentedLink: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(spacing: ROCKSTheme.spacingSM) {
                NavigationLink(destination: NewsView()) {
                    ROCKSMenuRow(title: "ROCKS News", systemImage: "newspaper.fill", subtitle: "Latest updates from across the organization")
                }
                .buttonStyle(.plain)

                Button {
                    appState.selectedTab = .learn
                } label: {
                    ROCKSMenuRow(title: "Program Guides", systemImage: "briefcase.fill", subtitle: "Mentorship, leadership, and scholarship programs")
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ChapterListView()) {
                    ROCKSMenuRow(title: "Chapter Directory", systemImage: "mappin.and.ellipse", subtitle: "Find chapters and local leadership")
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ScholarshipsView()) {
                    ROCKSMenuRow(title: "Scholarship Center", systemImage: "graduationcap.fill", subtitle: "Deadlines and application guidance")
                }
                .buttonStyle(.plain)

                OfficialLinkRow(title: "Official ROCKS Website", subtitle: "The organization’s official homepage", systemImage: "globe") {
                    presentedLink = IdentifiableURL(url: OfficialLinks.website)
                }

                OfficialLinkRow(title: "Programs Information", subtitle: "Program information published by The ROCKS", systemImage: "briefcase.fill") {
                    presentedLink = IdentifiableURL(url: OfficialLinks.programs)
                }

                OfficialLinkRow(title: "Membership Information", subtitle: "Official membership overview", systemImage: "person.badge.key.fill") {
                    presentedLink = IdentifiableURL(url: OfficialLinks.membershipInformation)
                }

                OfficialLinkRow(title: "General Information", subtitle: "Mission, vision, values, and goals", systemImage: "info.circle") {
                    presentedLink = IdentifiableURL(url: OfficialLinks.generalInformation)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .background(ROCKSColor.background)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
        .officialLinkSheet($presentedLink)
    }
}

/// Photo-forward media gallery built from the bundled branded assets.
struct MediaView: View {
    private let items: [(title: String, subtitle: String, image: String)] = [
        ("Leadership in Action", "National conference highlights", "rocksHeroLeadership"),
        ("Mentorship Moments", "Mentors and mentees across chapters", "rocksMentorship"),
        ("Leadership Development", "Professional growth programming", "rocksLeadership"),
        ("Scholarship Recipients", "Celebrating academic achievement", "rocksScholarship"),
        ("Community Service", "Serving the communities we call home", "rocksCommunityService")
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ROCKSTheme.spacingMD) {
                ForEach(items, id: \.title) { item in
                    ZStack(alignment: .bottomLeading) {
                        Image(item.image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 190)
                            .clipped()
                        LinearGradient.rocksPhotoScrim
                            .frame(height: 190)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(ROCKSColor.onDarkText.opacity(0.9))
                        }
                        .padding(16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Media")
        .navigationBarTitleDisplayMode(.inline)
    }
}
