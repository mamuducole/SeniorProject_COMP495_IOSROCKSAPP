import SwiftUI

/// Entry shape for the member directory. The app ships with no member data:
/// profiles appear only when an authorized integration supplies records the
/// signed-in member is permitted to see.
struct DirectoryMember: Identifiable, Hashable {
    let id: UUID
    let name: String
    let chapter: String?
    let position: String?
    let email: String?

    func matches(searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return name.localizedCaseInsensitiveContains(query)
            || (chapter?.localizedCaseInsensitiveContains(query) ?? false)
            || (position?.localizedCaseInsensitiveContains(query) ?? false)
    }
}

/// Member directory. Until an authorized directory integration is available,
/// this screen presents a privacy-friendly informational state and routes
/// members to the official ClubExpress-authenticated directory.
struct MemberDirectoryView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedChapter: String?
    @State private var selectedPosition: String?
    @State private var presentedLink: IdentifiableURL?

    /// Populated only by an authorized integration; never fabricated.
    private let members: [DirectoryMember] = []

    private var chapters: [String] {
        Array(Set(members.compactMap(\.chapter))).sorted()
    }

    private var positions: [String] {
        Array(Set(members.compactMap(\.position))).sorted()
    }

    private var filteredMembers: [DirectoryMember] {
        members.filter { member in
            member.matches(searchText: searchText)
                && (selectedChapter == nil || member.chapter == selectedChapter)
                && (selectedPosition == nil || member.position == selectedPosition)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                searchBar

                if !members.isEmpty {
                    filterRow
                }

                if filteredMembers.isEmpty {
                    privacyFriendlyState
                } else {
                    ForEach(filteredMembers) { member in
                        memberRow(member)
                    }
                }

                officialDirectoryCard

                NavigationLink(destination: MentorshipHomeView()) {
                    ROCKSMenuRow(
                        title: "Opted-in mentors",
                        systemImage: "person.2.fill",
                        subtitle: "Browse members who chose to share a mentorship profile"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Member Directory")
        .navigationBarTitleDisplayMode(.inline)
        .officialLinkSheet($presentedLink)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ROCKSColor.subtleText)
                .accessibilityHidden(true)
            TextField("Search by name, chapter, or position", text: $searchText)
                .font(.subheadline)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityLabel("Search members")
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
    }

    private var filterRow: some View {
        HStack(spacing: 10) {
            filterMenu(title: "Chapter", selection: $selectedChapter, options: chapters)
            filterMenu(title: "Position", selection: $selectedPosition, options: positions)
            Spacer()
        }
    }

    private func filterMenu(title: String, selection: Binding<String?>, options: [String]) -> some View {
        Menu {
            Button("All") { selection.wrappedValue = nil }
            ForEach(options, id: \.self) { option in
                Button(option) { selection.wrappedValue = option }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selection.wrappedValue ?? title)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(ROCKSColor.goldText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ROCKSColor.cardBackground, in: Capsule())
            .overlay(Capsule().stroke(ROCKSColor.divider, lineWidth: 1))
        }
        .accessibilityLabel("Filter by \(title)")
    }

    private func memberRow(_ member: DirectoryMember) -> some View {
        ROCKSCard {
            HStack(spacing: 12) {
                Circle()
                    .fill(ROCKSColor.gold.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(ROCKSColor.goldText))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.primaryText)
                    if let chapter = member.chapter {
                        Text(chapter)
                            .font(.subheadline)
                            .foregroundStyle(ROCKSColor.subtleText)
                    }
                    if let position = member.position {
                        Text(position)
                            .font(.caption)
                            .foregroundStyle(ROCKSColor.goldText)
                    }
                }
                Spacer()
            }
        }
    }

    private var privacyFriendlyState: some View {
        ROCKSCard {
            VStack(alignment: .center, spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.largeTitle)
                    .foregroundStyle(ROCKSColor.goldText)
                    .accessibilityHidden(true)
                Text("Directory Protected")
                    .font(.headline)
                    .foregroundStyle(ROCKSColor.primaryText)
                Text("Member information is private. Directory access is managed through the official ROCKS member portal, which verifies your membership before showing member details.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    private var officialDirectoryCard: some View {
        VStack(spacing: 10) {
            if appState.isDemoUser {
                Label("Official directory sign-in is unavailable in demo mode.", systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ROCKSColor.subtleText)
                    .frame(maxWidth: .infinity, minHeight: 52)
            } else {
                Button {
                    presentedLink = IdentifiableURL(url: OfficialLinks.memberLogin)
                } label: {
                    Label("View Member Directory", systemImage: "person.3.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(ROCKSColor.black)
                        .background(ROCKSColor.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityHint("Opens the official member portal sign-in")
            }

            Text("Sign in with your ROCKS membership on the official website to access member information you are authorized to view.")
                .font(.caption)
                .foregroundStyle(ROCKSColor.subtleText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        MemberDirectoryView()
    }
    .environment(AppState.preview)
}
