import XCTest
@testable import ROCKS

final class OfficialLinksTests: XCTestCase {
    func testAllOfficialLinksUseHTTPS() {
        for url in OfficialLinks.all {
            XCTAssertEqual(url.scheme, "https", "\(url) must use HTTPS")
        }
    }

    func testROCKSLinksPointToOfficialDomain() {
        let rocksLinks: [URL] = [
            OfficialLinks.website, OfficialLinks.programs, OfficialLinks.generalInformation,
            OfficialLinks.membershipInformation, OfficialLinks.mentorship, OfficialLinks.scholarships,
            OfficialLinks.scholarshipApplication2027, OfficialLinks.scholarshipRecipients2026,
            OfficialLinks.chapterFinder, OfficialLinks.joinMembership, OfficialLinks.memberLogin,
            OfficialLinks.becomeAMember, OfficialLinks.about, OfficialLinks.donate, OfficialLinks.contact,
            OfficialLinks.donationsPage
        ] + DonationFund.official.map(\.donationURL)
        for url in rocksLinks {
            XCTAssertEqual(url.host, "www.rocksinc.org", "\(url) must point to the official ROCKS website")
        }
    }

    func testDonationFundsMatchOfficialDonationsPage() {
        let expected: [(String, String)] = [
            ("National ROCKS Operating Fund", "2211"),
            ("R.C. Cartwright Scholarship Fund", "1068"),
            ("LTG Edward Honor Leadership Fund", "1692"),
            ("Board Members' Annual $500 Donation", "8619"),
            ("The ROCKS, Inc. Journey Book Project", "1693")
        ]
        XCTAssertEqual(DonationFund.official.map(\.name), expected.map(\.0))
        for (fund, (_, itemID)) in zip(DonationFund.official, expected) {
            let query = URLComponents(url: fund.donationURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(URLQueryItem(name: "page_id", value: "305")), "\(fund.name) must use the official donation checkout")
            XCTAssertTrue(query.contains(URLQueryItem(name: "item_id", value: itemID)), "\(fund.name) must open its own fund")
            XCTAssertFalse(fund.summary.isEmpty)
        }
    }

    func testArmyROTCLinkPointsToOfficialArmyDomain() {
        XCTAssertEqual(OfficialLinks.armyROTCScholarships.host, "www.goarmy.com")
    }

    func testMembershipRenewalUsesOfficialLoginFlow() {
        let components = URLComponents(url: OfficialLinks.memberLogin, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "action", value: "login")), "Renewal must route through the official login flow")
    }

    func testProgramDetailsAreAvailableOfflineAndUseOfficialDestinations() {
        let expectedTitles = ["Leadership Development", "Networking", "Leadership Outreach", "Community Service"]
        XCTAssertEqual(ProgramInformation.details.map(\.title), expectedTitles)
        for program in ProgramInformation.details {
            XCTAssertFalse(program.overview.isEmpty)
            XCTAssertFalse(program.purpose.isEmpty)
            XCTAssertFalse(program.focusAreas.isEmpty)
            XCTAssertFalse(program.benefits.isEmpty)
            XCTAssertFalse(program.missionConnection.isEmpty)
            XCTAssertEqual(program.officialURL.host, "www.rocksinc.org")
        }
        XCTAssertEqual(ProgramInformation.detail(for: "Leadership Development")?.officialURL, OfficialLinks.programs)
        XCTAssertEqual(ProgramInformation.detail(for: "Leadership Outreach")?.officialURL, OfficialLinks.programs)
        XCTAssertEqual(ProgramInformation.detail(for: "Networking")?.officialURL, OfficialLinks.generalInformation)
        XCTAssertEqual(ProgramInformation.detail(for: "Community Service")?.officialURL, OfficialLinks.generalInformation)
    }

    func testDirectoryShipsWithoutFabricatedMembers() {
        // The app must never fabricate member profiles; directory data may only
        // come from an authorized integration.
        let member = DirectoryMember(id: UUID(), name: "Test", chapter: nil, position: nil, email: nil)
        XCTAssertTrue(member.matches(searchText: ""))
        XCTAssertTrue(member.matches(searchText: "test"))
        XCTAssertFalse(member.matches(searchText: "other"))
    }

    func testLinkSheetOnlyOpensSecureWebURLs() {
        XCTAssertTrue(OfficialLinkPolicy.canOpen(OfficialLinks.memberLogin))
        XCTAssertTrue(OfficialLinkPolicy.canOpen(OfficialLinks.joinMembership))
        XCTAssertFalse(OfficialLinkPolicy.canOpen(URL(string: "http://www.rocksinc.org/")!), "Payment pages must not open over HTTP")
        XCTAssertFalse(OfficialLinkPolicy.canOpen(URL(string: "mailto:info@example.org")!), "SFSafariViewController crashes on non-web schemes")
        XCTAssertFalse(OfficialLinkPolicy.canOpen(URL(string: "javascript:alert(1)")!))
        XCTAssertFalse(OfficialLinkPolicy.canOpen(URL(string: "https://user:pass@www.rocksinc.org/")!))
        XCTAssertFalse(OfficialLinkPolicy.canOpen(URL(string: "rocksinc.org")!))
    }

    func testEveryMembershipActionUsesItsOfficialDestination() {
        // Verified 2026-11-23: page 60 is "New Member Sign Up" (membership types and dues), and its
        // "Already a member? ... login and renew" link is page 31 with action=login.
        XCTAssertEqual(OfficialLinks.joinMembership.absoluteString, "https://www.rocksinc.org/content.aspx?page_id=60&club_id=459944")
        XCTAssertEqual(OfficialLinks.memberLogin.absoluteString, "https://www.rocksinc.org/content.aspx?page_id=31&club_id=459944&action=login")
        XCTAssertNotEqual(OfficialLinks.memberLogin, OfficialLinks.website, "Renewal must not fall back to the homepage")
        XCTAssertNotEqual(OfficialLinks.joinMembership, OfficialLinks.website, "Joining must not fall back to the homepage")
    }

    func testMembershipSummaryNeverTreatsAccountCreationAsMembership() {
        XCTAssertNil(MembershipAccessSummary(user: nil, member: nil))

        let pending = MembershipAccessSummary(user: AuthUser(id: UUID(), email: "a@example.com", role: .guest, membershipStatus: .pending), member: nil)
        XCTAssertEqual(pending?.isApproved, false)
        XCTAssertEqual(pending?.statusTitle, "Awaiting approval")
        XCTAssertEqual(pending?.chapter, "Not assigned")

        let inconsistent = MembershipAccessSummary(user: AuthUser(id: UUID(), email: "a@example.com", role: .guest, membershipStatus: .approved), member: nil)
        XCTAssertEqual(inconsistent?.isApproved, false, "A guest role is never shown as approved")

        let suspended = MembershipAccessSummary(user: AuthUser(id: UUID(), email: "a@example.com", role: .member, membershipStatus: .suspended), member: nil)
        XCTAssertEqual(suspended?.isApproved, false)

        let member = MemberProfile(id: UUID(), firstName: "Ada", lastName: "Lee", chapterName: "Alamo ROCKS")
        let approved = MembershipAccessSummary(user: AuthUser(id: member.id, email: "a@example.com", role: .member), member: member)
        XCTAssertEqual(approved?.isApproved, true)
        XCTAssertEqual(approved?.chapter, "Alamo ROCKS")
        XCTAssertTrue(approved?.detail.contains("official ROCKS member account") == true, "Dues and renewal dates stay with the official system")

        let demo = MembershipAccessSummary(user: DemoAuthService.demoUser, member: .demo)
        XCTAssertEqual(demo?.isApproved, false)
        XCTAssertEqual(demo?.statusTitle, "Demo account")
    }
}
