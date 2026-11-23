import Foundation

/// Verified destinations on the official ROCKS, Inc. website.
///
/// Every URL below was confirmed against the live https://www.rocksinc.org
/// site (ClubExpress, club_id 459944). Keep this file as the single source of
/// truth for external links so destinations stay auditable and consistent.
enum OfficialLinks {
    /// Official ROCKS, Inc. homepage.
    static let website = URL(string: "https://www.rocksinc.org/")!

    /// Official Programs overview.
    static let programs = URL(string: "https://www.rocksinc.org/content.aspx?club_id=459944&module_id=54327&page_id=22")!

    /// Official General Information: mission, vision, values, and goals.
    static let generalInformation = URL(string: "https://www.rocksinc.org/content.aspx?club_id=459944&module_id=51119&page_id=22")!

    /// Official membership overview and eligibility information.
    static let membershipInformation = URL(string: "https://www.rocksinc.org/content.aspx?club_id=459944&module_id=123586&page_id=22")!

    /// Programs → Mentorship page describing the CHAMP mentorship platform.
    static let mentorship = URL(string: "https://www.rocksinc.org/content.aspx?page_id=22&club_id=459944&module_id=793957")!

    /// Programs → Scholarship page (Honor / Cartwright scholarships).
    static let scholarships = URL(string: "https://www.rocksinc.org/content.aspx?page_id=22&club_id=459944&module_id=793958")!

    /// 2027 ROCKS, Inc. scholarship application (official PDF link).
    static let scholarshipApplication2027 = URL(string: "https://www.rocksinc.org/handlers/celinks.ashx?id=173776&club_id=459944")!

    /// 2026 scholarship recipients announcement (official PDF link).
    static let scholarshipRecipients2026 = URL(string: "https://www.rocksinc.org/docs.ashx?id=1786857&club_id=459944")!

    /// U.S. Army ROTC scholarship information referenced from the scholarship page.
    static let armyROTCScholarships = URL(string: "https://www.goarmy.com/careers-and-jobs/find-your-path/army-officers/rotc/scholarships")!

    /// Interactive chapter finder on the official website.
    static let chapterFinder = URL(string: "https://www.rocksinc.org/content.aspx?page_id=225&club_id=459944")!

    /// New member sign-up wizard (ClubExpress).
    static let joinMembership = URL(string: "https://www.rocksinc.org/content.aspx?page_id=60&club_id=459944")!

    /// Member login. Membership renewal is completed inside the member
    /// account area after signing in, per the official join page.
    static let memberLogin = URL(string: "https://www.rocksinc.org/content.aspx?page_id=31&club_id=459944&action=login")!

    /// "Become a Member" information page (eligibility and benefits).
    static let becomeAMember = URL(string: "https://www.rocksinc.org/content.aspx?page_id=22&club_id=459944&module_id=793953")!

    /// About The ROCKS, Inc. (vision and mission).
    static let about = URL(string: "https://www.rocksinc.org/content.aspx?page_id=22&club_id=459944&module_id=793952")!

    /// Official donation page.
    static let donate = URL(string: "https://www.rocksinc.org/content.aspx?page_id=22&club_id=459944&module_id=793969")!

    /// Official Donations page listing every fund (ClubExpress page 301).
    static let donationsPage = URL(string: "https://www.rocksinc.org/content.aspx?club_id=459944&page_id=301")!

    /// Fund-specific donation checkouts linked from the official Donations page (ClubExpress page 305).
    static let donateOperatingFund = URL(string: "https://www.rocksinc.org/content.aspx?page_id=305&club_id=459944&item_id=2211")!
    static let donateCartwrightScholarshipFund = URL(string: "https://www.rocksinc.org/content.aspx?page_id=305&club_id=459944&item_id=1068")!
    static let donateHonorLeadershipFund = URL(string: "https://www.rocksinc.org/content.aspx?page_id=305&club_id=459944&item_id=1692")!
    static let donateBoardMembersAnnual = URL(string: "https://www.rocksinc.org/content.aspx?page_id=305&club_id=459944&item_id=8619")!
    static let donateJourneyBookProject = URL(string: "https://www.rocksinc.org/content.aspx?page_id=305&club_id=459944&item_id=1693")!

    /// Contact Us page (web contact form; the organization publishes no email address).
    static let contact = URL(string: "https://www.rocksinc.org/content.aspx?page_id=4&club_id=459944")!

    /// All links the app exposes, used by tests to validate security requirements.
    static let all: [URL] = [
        website, programs, generalInformation, membershipInformation, mentorship, scholarships, scholarshipApplication2027,
        scholarshipRecipients2026, armyROTCScholarships, chapterFinder,
        joinMembership, memberLogin, becomeAMember, about, donate, donationsPage,
        donateOperatingFund, donateCartwrightScholarshipFund, donateHonorLeadershipFund,
        donateBoardMembersAnnual, donateJourneyBookProject, contact
    ]
}
