import Foundation

enum PostKind: String, Codable, Sendable, CaseIterable {
    case member
    case announcement
    case scholarship
    case program

    var isOfficial: Bool { self != .member }

    var badgeTitle: String {
        switch self {
        case .member: ""
        case .announcement: "ROCKS Announcement"
        case .scholarship: "Scholarship"
        case .program: "Program Update"
        }
    }
}

struct Post: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let author: MemberProfile
    let kind: PostKind
    let body: String
    let imageName: String?
    let imageURL: URL?
    let createdAt: Date
    let editedAt: Date?
    var likeCount: Int
    var isLikedByCurrentUser: Bool
    var comments: [PostComment]

    /// Maximum characters accepted by the `posts_body_length` database constraint.
    static let maxBodyLength = 2000

    init(
        id: UUID,
        author: MemberProfile,
        kind: PostKind = .member,
        body: String,
        imageName: String? = nil,
        imageURL: URL? = nil,
        createdAt: Date,
        editedAt: Date? = nil,
        likeCount: Int = 0,
        isLikedByCurrentUser: Bool = false,
        comments: [PostComment] = []
    ) {
        self.id = id
        self.author = author
        self.kind = kind
        self.body = body
        self.imageName = imageName
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.likeCount = likeCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.comments = comments
    }

    var commentCount: Int { comments.count }

    /// Only plain member posts can be edited by their author (mirrors the RLS update policy).
    func canEdit(as userID: UUID?) -> Bool {
        kind == .member && isAuthored(by: userID)
    }

    func canDelete(as userID: UUID?) -> Bool {
        isAuthored(by: userID)
    }

    private func isAuthored(by userID: UUID?) -> Bool {
        guard let userID else { return false }
        return author.id == userID
    }

    func replacingBody(_ newBody: String, editedAt: Date) -> Post {
        Post(
            id: id,
            author: author,
            kind: kind,
            body: newBody,
            imageName: imageName,
            imageURL: imageURL,
            createdAt: createdAt,
            editedAt: editedAt,
            likeCount: likeCount,
            isLikedByCurrentUser: isLikedByCurrentUser,
            comments: comments
        )
    }

    static let examples: [Post] = {
        let members = MemberProfile.examples
        return [
            Post(
                id: UUID(uuidString: "30000000-0000-0000-0000-000000000001") ?? UUID(),
                author: members[1], // Jessica Williams
                body: "Honored to speak at today's Mentorship Mixer. Grateful for the leaders who invest in others. #ROCKSImpact #MentorshipMatters",
                imageName: "rocksCommunityService",
                createdAt: Calendar.current.date(byAdding: .hour, value: -5, to: .now) ?? .now,
                likeCount: 45,
                comments: [
                    PostComment(
                        id: UUID(uuidString: "31000000-0000-0000-0000-000000000001") ?? UUID(),
                        author: members[4],
                        body: "Outstanding session — thank you for sharing your story.",
                        createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: .now) ?? .now
                    )
                ]
            ),
            Post(
                id: UUID(uuidString: "30000000-0000-0000-0000-000000000002") ?? UUID(),
                author: MemberProfile(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000050") ?? UUID(),
                    firstName: "ROCKS",
                    lastName: "National",
                    role: .nationalAdmin,
                    rankTitle: "National Board",
                    chapterName: "Headquarters"
                ),
                kind: .scholarship,
                body: "Applications for the 2025 National Scholarship are now open! Invest in your future. The deadline is July 15.",
                imageName: "rocksScholarship",
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
                likeCount: 112,
                comments: []
            ),
            Post(
                id: UUID(uuidString: "30000000-0000-0000-0000-000000000003") ?? UUID(),
                author: members[0], // Marcus Johnson
                kind: .member,
                body: "Proud of our newest mentee cohort. Six months of goals, check-ins, and growth — this is what Service, Mentorship, and Leadership look like in action.",
                createdAt: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now,
                likeCount: 67,
                comments: [
                    PostComment(
                        id: UUID(uuidString: "31000000-0000-0000-0000-000000000002") ?? UUID(),
                        author: members[3],
                        body: "Incredible work, Marcus. Our chapter is inspired.",
                        createdAt: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
                    ),
                    PostComment(
                        id: UUID(uuidString: "31000000-0000-0000-0000-000000000003") ?? UUID(),
                        author: members[5],
                        body: "Looking forward to joining the next cohort!",
                        createdAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
                    )
                ]
            )
        ]
    }()
}

struct PostComment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let author: MemberProfile
    let body: String
    let createdAt: Date

    /// Maximum characters accepted by the `post_comments_body_length` database constraint.
    static let maxBodyLength = 1000

    func canDelete(as userID: UUID?) -> Bool {
        guard let userID else { return false }
        return author.id == userID
    }
}
