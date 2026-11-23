import SwiftUI

/// Scholarship information sourced from the official ROCKS, Inc. website.
/// Content reflects the published Honor / Cartwright scholarship program;
/// applications and announcements open on official destinations only.
struct ScholarshipInfoView: View {
    @Environment(AppState.self) private var appState
    @State private var presentedLink: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                overviewCard

                currentOpportunityCard

                pastAnnouncementsCard

                relatedResourcesCard

                Text("Award amounts for The ROCKS scholarship are not published on the official website. Always confirm details on the official scholarship page before applying.")
                    .font(.caption)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Scholarships")
        .navigationBarTitleDisplayMode(.inline)
        .officialLinkSheet($presentedLink)
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [ROCKSColor.black, ROCKSColor.charcoal], startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 190)

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.title2)
                    .foregroundStyle(ROCKSColor.black)
                    .frame(width: 44, height: 44)
                    .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                Text("Scholarships")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("Investing in the next generation of military leaders.")
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
                Text("The National Board of The ROCKS, Inc. awards annual scholarships to outstanding ROTC cadets who demonstrate academic excellence, leadership, character, and commitment to service. These scholarships honor Lieutenant General (Ret.) Edward Honor and Brigadier General (Ret.) Roscoe C. Cartwright, and are open to Army, Air Force, Marine Corps, and Navy ROTC cadets at colleges, universities, and military schools across the United States.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var currentOpportunityCard: some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Current Opportunity")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(ROCKSColor.primaryText)
                    Spacer()
                    Text("OPEN")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ROCKSColor.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ROCKSColor.gold, in: Capsule())
                        .accessibilityLabel("Currently open")
                }

                Text("2027 ROCKS, Inc. Scholarship")
                    .font(.headline)
                    .foregroundStyle(ROCKSColor.primaryText)

                detailRow(icon: "calendar", label: "Application deadline", value: "26 March 2027")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Eligibility highlights")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.primaryText)
                    bullet("Endorsement letter from your ROTC Professor of Military Science")
                    bullet("Strong character — leads by example")
                    bullet("Inspires others toward military service")
                    bullet("Demonstrated dedication to academic and personal growth")
                }

                if appState.isDemoUser {
                    Label("Applications are disabled in demo mode.", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.subtleText)
                        .frame(maxWidth: .infinity, minHeight: 50)
                } else {
                    Button {
                        presentedLink = IdentifiableURL(url: OfficialLinks.scholarshipApplication2027)
                    } label: {
                        Label("Apply Now", systemImage: "square.and.pencil")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(ROCKSColor.black)
                            .background(ROCKSColor.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityHint("Opens the official 2027 scholarship application")
                }

                Button {
                    presentedLink = IdentifiableURL(url: OfficialLinks.scholarships)
                } label: {
                    Label("View Scholarship Details", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(ROCKSColor.goldText)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ROCKSColor.goldText, lineWidth: 1))
                }
                .accessibilityHint("Opens the official scholarship page")
            }
        }
    }

    private var pastAnnouncementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Past Announcements")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ROCKSColor.primaryText)
            OfficialLinkRow(title: "2026 Scholarship Recipients", subtitle: "Official announcement (PDF)", systemImage: "trophy") {
                presentedLink = IdentifiableURL(url: OfficialLinks.scholarshipRecipients2026)
            }
        }
    }

    private var relatedResourcesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Related Resources")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ROCKSColor.primaryText)
            OfficialLinkRow(title: "Army ROTC National Scholarship", subtitle: "Scholarship information on goarmy.com", systemImage: "shield.lefthalf.filled") {
                presentedLink = IdentifiableURL(url: OfficialLinks.armyROTCScholarships)
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(ROCKSColor.goldText)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ROCKSColor.primaryText)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(ROCKSColor.gold)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        ScholarshipInfoView()
    }
    .environment(AppState.preview)
}
