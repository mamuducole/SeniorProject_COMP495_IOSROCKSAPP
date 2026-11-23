import Network
import SwiftUI

/// An official ROCKS, Inc. donation fund. Names, descriptions, and checkout
/// links mirror the official Donations page and are bundled with the app so
/// the Donate screen renders without a network connection.
struct DonationFund: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let systemImage: String
    let donationURL: URL

    static let official: [DonationFund] = [
        DonationFund(
            id: "operating",
            name: "National ROCKS Operating Fund",
            summary: "Supports the organization's administrative and operating expenses.",
            systemImage: "building.columns.fill",
            donationURL: OfficialLinks.donateOperatingFund
        ),
        DonationFund(
            id: "cartwright-scholarship",
            name: "R.C. Cartwright Scholarship Fund",
            summary: "Supports the scholarship initiatives maintained and delivered by The ROCKS, Inc.",
            systemImage: "graduationcap.fill",
            donationURL: OfficialLinks.donateCartwrightScholarshipFund
        ),
        DonationFund(
            id: "honor-leadership",
            name: "LTG Edward Honor Leadership Fund",
            summary: "Supports a leadership award honoring an outstanding graduating college senior.",
            systemImage: "rosette",
            donationURL: OfficialLinks.donateHonorLeadershipFund
        ),
        DonationFund(
            id: "board-members-annual",
            name: "Board Members' Annual $500 Donation",
            summary: "Provides an opportunity for board members to contribute financially to the organization.",
            systemImage: "person.3.fill",
            donationURL: OfficialLinks.donateBoardMembersAnnual
        ),
        DonationFund(
            id: "journey-book",
            name: "The ROCKS, Inc. Journey Book Project",
            summary: "Supports the organization's historical publication documenting ROCKS history and achievements.",
            systemImage: "book.closed.fill",
            donationURL: OfficialLinks.donateJourneyBookProject
        )
    ]
}

/// Tracks whether the device currently has a usable network path.
@MainActor
@Observable
final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()

    /// Assumed reachable until the first path update arrives so a slow update never blocks giving.
    private(set) var isConnected: Bool
    private let monitor: NWPathMonitor?

    init(isConnected: Bool = true, monitorsNetwork: Bool = true) {
        self.isConnected = isConnected
        guard monitorsNetwork else {
            monitor = nil
            return
        }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in self?.isConnected = connected }
        }
        monitor.start(queue: DispatchQueue(label: "org.rocksinc.ROCKS.connectivity"))
    }
}

/// Donate screen: presents the official funds and hands every gift off to the
/// official ROCKS, Inc. website. The app never collects or stores payment data.
struct DonateView: View {
    static let offlineMessage = "An internet connection is required to open the official donation website."

    @Environment(AppState.self) private var appState
    var connectivity: ConnectivityMonitor = .shared
    var funds: [DonationFund] = DonationFund.official

    @State private var presentedLink: IdentifiableURL?
    @State private var showingOfflineAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ROCKSTheme.spacingLG) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Choose a Fund to Support")
                    ForEach(funds) { fund in
                        fundCard(fund)
                    }
                }

                infoCard(
                    title: "Why Your Support Matters",
                    systemImage: "heart.fill",
                    text: "Contributions help The ROCKS, Inc. carry out its mission by funding scholarship opportunities, leadership development, mentorship, and the organizational operations that keep national and chapter programs running."
                )

                secureGivingCard

                Text("The ROCKS, Inc. is a 501(c)(3) organization. Gifts may be tax-deductible.")
                    .font(.caption)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Donate")
        .navigationBarTitleDisplayMode(.inline)
        .officialLinkSheet($presentedLink)
        .alert("No Internet Connection", isPresented: $showingOfflineAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(Self.offlineMessage)
        }
    }

    private func open(_ url: URL) {
        guard !appState.isDemoUser else { return }
        if connectivity.isConnected {
            presentedLink = IdentifiableURL(url: url)
        } else {
            showingOfflineAlert = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            ROCKSLogoHeader(size: .large, showsTagline: true)
            Text("Support the ROCKS Mission")
                .font(ROCKSFont.titleSmall)
                .foregroundStyle(ROCKSColor.onDarkText)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your contribution helps support mentorship, scholarships, leadership development, and the continued mission of The ROCKS, Inc.")
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.onDarkText.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient.rocksBranded, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(ROCKSColor.goldStroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(ROCKSColor.primaryText)
            .accessibilityAddTraits(.isHeader)
    }

    private func fundCard(_ fund: DonationFund) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: fund.systemImage)
                    .font(.title3)
                    .foregroundStyle(ROCKSColor.goldText)
                    .frame(width: 46, height: 46)
                    .background(ROCKSColor.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(fund.name)
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(fund.summary)
                        .font(.subheadline)
                        .foregroundStyle(ROCKSColor.subtleText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                open(fund.donationURL)
            } label: {
                HStack(spacing: 8) {
                    Text("Donate to This Fund")
                        .font(.headline)
                    Image(systemName: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(ROCKSColor.black)
                .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(appState.isDemoUser)
            .accessibilityLabel("Donate to \(fund.name)")
            .accessibilityHint(appState.isDemoUser ? "Unavailable in demo mode" : "Opens the official ROCKS donation website")
            if appState.isDemoUser {
                Text("Donations are disabled in demo mode.")
                    .font(.caption)
                    .foregroundStyle(ROCKSColor.subtleText)
            }
        }
        .padding(ROCKSTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
    }

    private func infoCard(title: String, systemImage: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ROCKSColor.primaryText)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(ROCKSColor.goldText)
            }
            .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ROCKSTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
    }

    private var secureGivingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoCard(
                title: "Secure Giving",
                systemImage: "lock.shield.fill",
                text: "Donations are completed through the official ROCKS, Inc. website. The ROCKS App does not process or store your payment information."
            )
            OfficialLinkRow(
                title: "View All Donation Options",
                subtitle: "Official ROCKS, Inc. Donations page",
                systemImage: "globe"
            ) {
                open(OfficialLinks.donationsPage)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DonateView()
    }
}
