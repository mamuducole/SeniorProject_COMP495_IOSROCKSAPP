import SwiftUI

/// Membership hub connecting to the official ROCKS, Inc. membership system
/// (ClubExpress). Renewal, payments, and sign-in all happen on the official
/// website; the app never collects passwords or payment details.
struct MembershipView: View {
    @Environment(AppState.self) private var appState
    @State private var presentedLink: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let summary = MembershipAccessSummary(user: appState.currentUser, member: appState.currentMember) {
                    MembershipAccessCard(summary: summary)
                }

                if appState.isDemoUser {
                    Label("Demo membership · renewal and payments are disabled", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.subtleText)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    renewButton
                    joinButton
                    actions
                }

                eligibilityCard

                Text("Membership sign-in, renewal, and payment are handled securely by the official ROCKS website. This app never collects or stores passwords or payment card details.")
                    .font(.caption)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Membership")
        .navigationBarTitleDisplayMode(.inline)
        .officialLinkSheet($presentedLink)
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [ROCKSColor.black, ROCKSColor.charcoal], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(alignment: .leading, spacing: 8) {
                Image("rocksLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)
                    .accessibilityLabel("The ROCKS, Inc. emblem")
                Text("Membership")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("Men of Service. Leaders for Life.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.onDarkText.opacity(0.9))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(ROCKSColor.goldStroke, lineWidth: 1))
    }

    private var renewButton: some View {
        Button {
            presentedLink = IdentifiableURL(url: OfficialLinks.memberLogin)
        } label: {
            Label("Renew Membership", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(ROCKSColor.black)
                .background(ROCKSColor.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityHint("Opens the official member login where renewal is completed")
    }

    private var joinButton: some View {
        Button {
            presentedLink = IdentifiableURL(url: OfficialLinks.joinMembership)
        } label: {
            Label("Join The ROCKS", systemImage: "person.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(ROCKSColor.goldText)
                .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ROCKSColor.gold, lineWidth: 1.5))
        }
        .accessibilityHint("Opens the official new member sign-up and dues page")
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Text("Existing members renew by signing in to their official member account. New members choose a membership type and pay dues on the official sign-up page.")
                .font(.caption)
                .foregroundStyle(ROCKSColor.subtleText)
                .frame(maxWidth: .infinity, alignment: .leading)

            OfficialLinkRow(title: "CHAMP Mentorship", subtitle: "Mentorship program on the official site", systemImage: "person.2.fill") {
                presentedLink = IdentifiableURL(url: OfficialLinks.mentorship)
            }
            OfficialLinkRow(title: "Membership Benefits & Eligibility", subtitle: "Become a Member page", systemImage: "checkmark.seal") {
                presentedLink = IdentifiableURL(url: OfficialLinks.becomeAMember)
            }
            OfficialLinkRow(title: "Contact The ROCKS", subtitle: "Questions about your membership", systemImage: "envelope") {
                presentedLink = IdentifiableURL(url: OfficialLinks.contact)
            }
        }
    }

    private var eligibilityCard: some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Who Can Join")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Text("The ROCKS serves military officers and warrant officers, ROTC and military academy cadets, midshipmen, and government civilians. Retired and former officers also help support the organization’s mission.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Review the official membership information for current eligibility and membership details.")
                    .font(.footnote)
                    .foregroundStyle(ROCKSColor.subtleText)
                OfficialLinkRow(title: "Official Membership Information", subtitle: "Membership overview and who the organization serves", systemImage: "globe") {
                    presentedLink = IdentifiableURL(url: OfficialLinks.membershipInformation)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MembershipView()
    }
    .environment(AppState.preview)
}

/// What the app knows about the signed-in account. ROCKS Connect access is approved by app
/// administrators; official dues, membership type, and expiration live on rocksinc.org.
struct MembershipAccessSummary: Equatable {
    let statusTitle: String
    let detail: String
    let chapter: String
    let isApproved: Bool

    init?(user: AuthUser?, member: MemberProfile?) {
        guard let user else { return nil }
        if user.isDemo {
            statusTitle = "Demo account"
            detail = "Sample data only. This is not a ROCKS membership."
            isApproved = false
        } else {
            switch user.membershipStatus {
            case .approved where user.role != .guest:
                statusTitle = "ROCKS Connect access approved"
                detail = "An administrator approved this account for member features. Dues, membership type, and renewal dates are managed in your official ROCKS member account."
                isApproved = true
            case .approved, .pending:
                statusTitle = "Awaiting approval"
                detail = "An administrator will review your account. Creating an app account does not make you a ROCKS member."
                isApproved = false
            case .declined:
                statusTitle = "Application not approved"
                detail = "Contact The ROCKS, Inc. if you believe this is a mistake."
                isApproved = false
            case .suspended:
                statusTitle = "Access suspended"
                detail = "Contact The ROCKS, Inc. for assistance."
                isApproved = false
            }
        }
        chapter = member?.chapterName ?? "Not assigned"
    }
}

struct MembershipAccessCard: View {
    let summary: MembershipAccessSummary

    var body: some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR ACCOUNT")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(ROCKSColor.goldText)
                Label(summary.statusTitle, systemImage: summary.isApproved ? "checkmark.seal.fill" : "hourglass")
                    .font(.headline)
                    .foregroundStyle(ROCKSColor.primaryText)
                Text(summary.detail)
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
                LabeledContent("Chapter", value: summary.chapter)
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.primaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
