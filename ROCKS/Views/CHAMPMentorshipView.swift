import SwiftUI

/// Mentorship screen built around the official CHAMP mentorship platform of
/// The ROCKS, Inc. Program details come from the official website; mentor
/// matching itself happens on the official platform after members sign in.
struct CHAMPMentorshipView: View {
    @Environment(AppState.self) private var appState
    @State private var presentedLink: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                overviewCard

                if appState.isDemoUser {
                    Label("External mentorship requests are disabled in demo mode.", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.subtleText)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    exploreButton
                }

                howItWorksCard

                NavigationLink(destination: MentorshipHomeView()) {
                    Label("Explore in-app mentorship", systemImage: "person.2")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)

                if !appState.isDemoUser {
                    moreActions
                }

                Text("CHAMP is managed on the official ROCKS platform. In-app mentorship is separate and stores its own requests and activities when available.")
                    .font(.caption)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Mentorship")
        .navigationBarTitleDisplayMode(.inline)
        .officialLinkSheet($presentedLink)
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [ROCKSColor.black, ROCKSColor.charcoal], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 190)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                        .foregroundStyle(ROCKSColor.black)
                        .frame(width: 44, height: 44)
                        .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)
                    Text("CHAMP")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }
                Text("The official mentorship platform of The ROCKS, Inc.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.onDarkText.opacity(0.9))
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var overviewCard: some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("About the Program")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Text("The ROCKS connects driven individuals, military and civilian, with experienced mentors, resources, and opportunities that support career advancement, leadership development, and long-term success. The work is intentionally relationship-driven: transformation occurs when people are consistently supported by mentors and leaders who model accountability, service, discipline, and achievement.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Once you join The ROCKS, you can “Become a Mentor” or “Find a Mentor” through the CHAMP platform.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var exploreButton: some View {
        Button {
            presentedLink = IdentifiableURL(url: OfficialLinks.mentorship)
        } label: {
            Label("Explore CHAMP", systemImage: "arrow.up.right.square.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(ROCKSColor.black)
                .background(ROCKSColor.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityHint("Opens the official ROCKS mentorship page")
    }

    private var howItWorksCard: some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("How to Participate")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                stepRow(number: "1", text: "Join The ROCKS, Inc. — membership is open to ROTC and Military Academy cadets, commissioned and warrant officers, and federal civilians GS-9 and above.")
                stepRow(number: "2", text: "Sign in on the official website to access the CHAMP platform.")
                stepRow(number: "3", text: "Choose “Become a Mentor” or “Find a Mentor” to start a mentorship connection.")
            }
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ROCKSColor.black)
                .frame(width: 26, height: 26)
                .background(ROCKSColor.gold, in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var moreActions: some View {
        VStack(spacing: 10) {
            OfficialLinkRow(title: "Become a Member", subtitle: "Eligibility and benefits on the official site", systemImage: "person.badge.plus") {
                presentedLink = IdentifiableURL(url: OfficialLinks.becomeAMember)
            }
            OfficialLinkRow(title: "Contact The ROCKS", subtitle: "Official contact form and phone number", systemImage: "envelope") {
                presentedLink = IdentifiableURL(url: OfficialLinks.contact)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CHAMPMentorshipView()
    }
    .environment(AppState.preview)
}
