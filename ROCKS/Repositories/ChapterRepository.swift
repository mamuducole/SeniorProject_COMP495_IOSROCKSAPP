import Foundation

protocol ChapterRepository: Sendable {
    func fetchChapters() async throws -> [Chapter]
    func fetchChapter(id: UUID) async throws -> Chapter?
}

struct AdministrativeActivity: Identifiable, Decodable, Sendable {
    let id: Int64
    let actorID: UUID?
    let action: String
    let resourceType: String
    let resourceID: UUID
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case id, action
        case actorID = "actor_id"
        case resourceType = "resource_type"
        case resourceID = "resource_id"
        case occurredAt = "occurred_at"
    }
}

protocol AdminRepository: Sendable {
    func fetchManagedChapters() async throws -> [Chapter]
    func updateChapter(id: UUID, description: String, email: String, website: String) async throws
    func fetchActivity() async throws -> [AdministrativeActivity]
    func fetchMembershipApplications(status: MembershipStatus) async throws -> [MembershipApplication]
    func reviewMembership(profileID: UUID, decision: MembershipDecision) async throws
    func fetchOpenReports() async throws -> [ContentReport]
    func resolveReport(id: UUID, dismissed: Bool) async throws
    func removeReportedContent(_ report: ContentReport) async throws
}

/// An account awaiting (or previously given) a membership decision, scoped by the server.
struct MembershipApplication: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
    let requestedChapterName: String?
    let status: MembershipStatus
    let termsAcceptedAt: Date?
    let createdAt: Date

    var fullName: String { "\(firstName) \(lastName)" }

    enum CodingKeys: String, CodingKey {
        case id = "profile_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case email, status
        case requestedChapterName = "requested_chapter_name"
        case termsAcceptedAt = "terms_accepted_at"
        case createdAt = "created_at"
    }
}

enum MembershipDecision: String, Sendable {
    case approve
    case decline
    case suspend
}

struct ContentReport: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let postID: UUID?
    let commentID: UUID?
    let reason: String
    let details: String?
    let reportedAt: Date
    let content: String?
    let authorName: String?
    let reportCount: Int

    var reasonTitle: String { ReportReason(rawValue: reason)?.title ?? reason.capitalized }

    enum CodingKeys: String, CodingKey {
        case id = "report_id"
        case postID = "post_id"
        case commentID = "comment_id"
        case reason, details, content
        case reportedAt = "reported_at"
        case authorName = "author_name"
        case reportCount = "report_count"
    }
}

struct MockChapterRepository: ChapterRepository {
    func fetchChapters() async throws -> [Chapter] {
        Chapter.examples
    }

    func fetchChapter(id: UUID) async throws -> Chapter? {
        Chapter.examples.first { $0.id == id }
    }
}
