import Foundation

protocol FeedRepository: Sendable {
    func fetchPosts() async throws -> [Post]
    func fetchPost(id: UUID) async throws -> Post?
    func createPost(body: String, imageName: String?) async throws -> Post
    func updatePost(id: UUID, body: String) async throws -> Post
    func deletePost(id: UUID) async throws
    func setLiked(postID: UUID, liked: Bool) async throws
    func addComment(postID: UUID, body: String) async throws -> PostComment
    func deleteComment(id: UUID, postID: UUID) async throws
    func report(_ target: ReportTarget, reason: ReportReason) async throws
}

enum ReportTarget: Hashable, Sendable {
    case post(UUID)
    case comment(UUID)
}

enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam
    case harassment
    case inappropriate
    case misinformation
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: "Spam"
        case .harassment: "Harassment or bullying"
        case .inappropriate: "Inappropriate content"
        case .misinformation: "False information"
        case .other: "Something else"
        }
    }
}

enum FeedValidation {
    static func postBody(_ body: String) throws -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.validation("Write something before posting.")
        }
        guard trimmed.count <= Post.maxBodyLength else {
            throw AppError.validation("Posts can be up to \(Post.maxBodyLength) characters.")
        }
        return trimmed
    }

    static func commentBody(_ body: String) throws -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.validation("Write a comment first.")
        }
        guard trimmed.count <= PostComment.maxBodyLength else {
            throw AppError.validation("Comments can be up to \(PostComment.maxBodyLength) characters.")
        }
        return trimmed
    }
}

/// Local, in-memory feed used by previews, tests, and the demo account.
/// Enforces the same ownership rules as the Supabase RLS policies.
actor MockFeedRepository: FeedRepository {
    private var posts: [Post]
    private let currentMember: MemberProfile

    init(posts: [Post] = Post.examples, currentMember: MemberProfile = .demo) {
        self.posts = posts
        self.currentMember = currentMember
    }

    func fetchPosts() async throws -> [Post] {
        posts.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchPost(id: UUID) async throws -> Post? {
        posts.first { $0.id == id }
    }

    func createPost(body: String, imageName: String?) async throws -> Post {
        let trimmed = try FeedValidation.postBody(body)
        let post = Post(
            id: UUID(),
            author: currentMember,
            body: trimmed,
            imageName: imageName,
            createdAt: .now
        )
        posts.insert(post, at: 0)
        return post
    }

    func updatePost(id: UUID, body: String) async throws -> Post {
        let trimmed = try FeedValidation.postBody(body)
        guard let index = posts.firstIndex(where: { $0.id == id }) else { throw AppError.unauthorized }
        guard posts[index].canEdit(as: currentMember.id) else { throw AppError.unauthorized }
        posts[index] = posts[index].replacingBody(trimmed, editedAt: .now)
        return posts[index]
    }

    func deletePost(id: UUID) async throws {
        guard let index = posts.firstIndex(where: { $0.id == id }) else { throw AppError.unauthorized }
        guard posts[index].canDelete(as: currentMember.id) else { throw AppError.unauthorized }
        posts.remove(at: index)
    }

    func setLiked(postID: UUID, liked: Bool) async throws {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        // Idempotent like the (post_id, profile_id) primary key: repeated likes never double count.
        guard posts[index].isLikedByCurrentUser != liked else { return }
        posts[index].isLikedByCurrentUser = liked
        posts[index].likeCount += liked ? 1 : -1
    }

    func addComment(postID: UUID, body: String) async throws -> PostComment {
        let trimmed = try FeedValidation.commentBody(body)
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            throw AppError.validation("This post is no longer available.")
        }
        let comment = PostComment(id: UUID(), author: currentMember, body: trimmed, createdAt: .now)
        posts[index].comments.append(comment)
        return comment
    }

    func deleteComment(id: UUID, postID: UUID) async throws {
        guard let postIndex = posts.firstIndex(where: { $0.id == postID }),
              let commentIndex = posts[postIndex].comments.firstIndex(where: { $0.id == id }) else {
            throw AppError.unauthorized
        }
        guard posts[postIndex].comments[commentIndex].canDelete(as: currentMember.id) else {
            throw AppError.unauthorized
        }
        posts[postIndex].comments.remove(at: commentIndex)
    }

    private(set) var reports: [ReportTarget: ReportReason] = [:]

    func report(_ target: ReportTarget, reason: ReportReason) async throws {
        guard reports[target] == nil else {
            throw AppError.validation("You already reported this. An administrator will review it.")
        }
        reports[target] = reason
    }
}
