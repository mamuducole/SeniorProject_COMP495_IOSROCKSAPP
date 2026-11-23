import Foundation

enum AppRole: String, Codable, CaseIterable, Sendable {
    case guest
    case member
    case mentor
    case chapterAdmin = "chapter_admin"
    case nationalAdmin = "national_admin"

    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

enum AuthenticationProvider: String, Codable, Sendable {
    case supabase
    case localDemo = "local_demo"
}

/// Organizational membership review state stored in `profiles.membership_status`.
enum MembershipStatus: String, Codable, Sendable {
    case pending
    case approved
    case declined
    case suspended

    var title: String {
        switch self {
        case .pending: "Application under review"
        case .approved: "Approved member"
        case .declined: "Application not approved"
        case .suspended: "Membership access suspended"
        }
    }
}

struct AuthUser: Codable, Equatable, Sendable {
    let id: UUID
    let email: String
    let role: AppRole
    let membershipStatus: MembershipStatus
    let authenticationProvider: AuthenticationProvider

    var isDemo: Bool { authenticationProvider == .localDemo }

    /// Mirrors the server rule: only approved, non-guest accounts may use member features.
    var hasMemberAccess: Bool { isDemo || (membershipStatus == .approved && role != .guest) }

    init(
        id: UUID,
        email: String,
        role: AppRole,
        membershipStatus: MembershipStatus = .approved,
        authenticationProvider: AuthenticationProvider = .supabase
    ) {
        self.id = id
        self.email = email
        self.role = role
        self.membershipStatus = membershipStatus
        self.authenticationProvider = authenticationProvider
    }
}

/// A member's public directory profile, mapped from the `profiles` table.
struct MemberProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String?
    let role: AppRole
    let rankTitle: String?
    let chapterName: String?
    let bio: String?
    let avatarURL: URL?

    init(
        id: UUID,
        firstName: String,
        lastName: String,
        email: String? = nil,
        role: AppRole = .member,
        rankTitle: String? = nil,
        chapterName: String? = nil,
        bio: String? = nil,
        avatarURL: URL? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.role = role
        self.rankTitle = rankTitle
        self.chapterName = chapterName
        self.bio = bio
        self.avatarURL = avatarURL
    }

    var fullName: String { "\(firstName) \(lastName)" }

    var headline: String {
        [rankTitle, chapterName].compactMap { $0 }.joined(separator: " \u{2022} ")
    }

    /// Avatar placeholder used by mocks so event attendee stacks render without remote images.
    static func placeholder(name: String) -> MemberProfile {
        let parts = name.split(separator: " ").map(String.init)
        return MemberProfile(
            id: UUID(uuidString: "90000000-0000-0000-0000-\(String(format: "%012d", abs(name.hashValue) % 999_999_999_999))") ?? UUID(),
            firstName: parts.first ?? name,
            lastName: parts.dropFirst().joined(separator: " ")
        )
    }

    static let examples = [
        MemberProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001") ?? UUID(),
            firstName: "Marcus",
            lastName: "Johnson",
            role: .mentor,
            rankTitle: "COL (Ret.)",
            chapterName: "National Capital Chapter",
            bio: "Career Army officer and lifelong mentor focused on developing the next generation of leaders."
        ),
        MemberProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002") ?? UUID(),
            firstName: "Jessica",
            lastName: "Williams",
            role: .member,
            rankTitle: "LTC",
            chapterName: "JB&IM Chapter",
            bio: "Logistics officer passionate about mentorship and professional development."
        ),
        MemberProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000003") ?? UUID(),
            firstName: "Kevin",
            lastName: "Roberts",
            role: .mentor,
            rankTitle: "CW5 (Ret.)",
            chapterName: "Fort Liberty Chapter",
            bio: "Professional development coach and former warrant officer advisor."
        ),
        MemberProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000004") ?? UUID(),
            firstName: "Angela",
            lastName: "Carter",
            role: .chapterAdmin,
            rankTitle: "MAJ",
            chapterName: "National Capital Chapter",
            bio: "Chapter president focused on scholarship and community programming."
        ),
        MemberProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000005") ?? UUID(),
            firstName: "David",
            lastName: "Thompson",
            role: .member,
            rankTitle: "CPT",
            chapterName: "Fort Liberty Chapter"
        ),
        MemberProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000006") ?? UUID(),
            firstName: "Monica",
            lastName: "Reed",
            role: .member,
            rankTitle: "1LT",
            chapterName: "National Capital Chapter"
        ),
        MemberProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000007") ?? UUID(),
            firstName: "James",
            lastName: "Cole",
            role: .member,
            rankTitle: "2LT",
            chapterName: "Fort Liberty Chapter"
        )
    ]

    /// The non-production profile shown by the local demo account.
    static let demo = MemberProfile(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000099") ?? UUID(),
        firstName: "ROCKS Demo",
        lastName: "Member",
        email: "demo@rocks.org",
        role: .member,
        bio: "Non-production demo account. Data and actions are local simulations."
    )
}
