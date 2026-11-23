import Foundation
import Observation

@MainActor
@Observable
final class FeedViewModel {
    private(set) var posts: [Post] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// Failure loading the feed itself; shown as a full error state when there is nothing to display.
    private(set) var loadErrorMessage: String?
    /// Failure of a member action (like, post, comment, delete); presented as an alert.
    var actionErrorMessage: String?

    var draftBody = ""
    private(set) var isPosting = false
    private(set) var likesInFlight: Set<UUID> = []
    private(set) var deletingPostIDs: Set<UUID> = []
    private(set) var deletingCommentIDs: Set<UUID> = []

    let currentUserID: UUID?
    private let environment: AppEnvironment

    /// National administrators may remove any post or comment; the server enforces this.
    let isModerator: Bool
    var noticeMessage: String?

    init(environment: AppEnvironment, currentUserID: UUID? = nil, isModerator: Bool = false) {
        self.environment = environment
        self.currentUserID = currentUserID
        self.isModerator = isModerator
    }

    func canDelete(_ post: Post) -> Bool { isModerator || post.canDelete(as: currentUserID) }
    func canDelete(_ comment: PostComment) -> Bool { isModerator || comment.canDelete(as: currentUserID) }

    func report(_ target: ReportTarget, reason: ReportReason) async {
        do {
            try await environment.feedRepository.report(target, reason: reason)
            noticeMessage = "Thank you. An administrator will review this report."
        } catch {
            actionErrorMessage = Self.message(for: error, fallback: "Unable to send your report.")
        }
    }

    var canSubmitDraft: Bool {
        let trimmed = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= Post.maxBodyLength && !isPosting
    }

    func post(id: UUID) -> Post? {
        posts.first { $0.id == id }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            posts = try await environment.feedRepository.fetchPosts()
            loadErrorMessage = nil
            hasLoaded = true
        } catch {
            loadErrorMessage = Self.message(for: error, fallback: "Unable to load the community feed right now.")
        }
    }

    func refreshPost(id: UUID) async {
        do {
            if let fresh = try await environment.feedRepository.fetchPost(id: id) {
                if let index = posts.firstIndex(where: { $0.id == id }) {
                    posts[index] = fresh
                } else {
                    posts.insert(fresh, at: 0)
                }
            } else {
                posts.removeAll { $0.id == id }
            }
        } catch {
            actionErrorMessage = Self.message(for: error, fallback: "Unable to refresh this post.")
        }
    }

    func toggleLike(for post: Post) async {
        guard !likesInFlight.contains(post.id),
              let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        likesInFlight.insert(post.id)
        defer { likesInFlight.remove(post.id) }

        let newValue = !posts[index].isLikedByCurrentUser

        // Optimistic update for a snappy feed; roll back on failure.
        posts[index].isLikedByCurrentUser = newValue
        posts[index].likeCount = max(0, posts[index].likeCount + (newValue ? 1 : -1))

        do {
            try await environment.feedRepository.setLiked(postID: post.id, liked: newValue)
        } catch {
            if let rollbackIndex = posts.firstIndex(where: { $0.id == post.id }) {
                posts[rollbackIndex].isLikedByCurrentUser = !newValue
                posts[rollbackIndex].likeCount = max(0, posts[rollbackIndex].likeCount + (newValue ? -1 : 1))
            }
            actionErrorMessage = Self.message(for: error, fallback: "Unable to update your like.")
        }
    }

    func addComment(_ body: String, to post: Post) async -> Bool {
        do {
            let comment = try await environment.feedRepository.addComment(postID: post.id, body: body)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].comments.append(comment)
            }
            return true
        } catch {
            actionErrorMessage = Self.message(for: error, fallback: "Unable to add your comment.")
            return false
        }
    }

    func deleteComment(_ comment: PostComment, from post: Post) async -> Bool {
        guard canDelete(comment) else {
            actionErrorMessage = AppError.unauthorized.errorDescription
            return false
        }
        guard !deletingCommentIDs.contains(comment.id) else { return false }
        deletingCommentIDs.insert(comment.id)
        defer { deletingCommentIDs.remove(comment.id) }

        do {
            try await environment.feedRepository.deleteComment(id: comment.id, postID: post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].comments.removeAll { $0.id == comment.id }
            }
            return true
        } catch {
            actionErrorMessage = Self.message(for: error, fallback: "Unable to delete this comment.")
            return false
        }
    }

    func publishDraft() async -> Bool {
        guard !isPosting else { return false }
        isPosting = true
        defer { isPosting = false }

        do {
            let post = try await environment.feedRepository.createPost(body: draftBody, imageName: nil)
            posts.insert(post, at: 0)
            draftBody = ""
            return true
        } catch {
            actionErrorMessage = Self.message(for: error, fallback: "Unable to publish your post.")
            return false
        }
    }

    func updatePost(_ post: Post, body: String) async -> Bool {
        guard post.canEdit(as: currentUserID) else {
            actionErrorMessage = AppError.unauthorized.errorDescription
            return false
        }
        guard !isPosting else { return false }
        isPosting = true
        defer { isPosting = false }

        do {
            let updated = try await environment.feedRepository.updatePost(id: post.id, body: body)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index] = updated
            }
            return true
        } catch {
            actionErrorMessage = Self.message(for: error, fallback: "Unable to save your changes.")
            return false
        }
    }

    func deletePost(_ post: Post) async -> Bool {
        guard canDelete(post) else {
            actionErrorMessage = AppError.unauthorized.errorDescription
            return false
        }
        guard !deletingPostIDs.contains(post.id) else { return false }
        deletingPostIDs.insert(post.id)
        defer { deletingPostIDs.remove(post.id) }

        do {
            try await environment.feedRepository.deletePost(id: post.id)
            posts.removeAll { $0.id == post.id }
            return true
        } catch {
            actionErrorMessage = Self.message(for: error, fallback: "Unable to delete this post.")
            return false
        }
    }

    private static func message(for error: Error, fallback: String) -> String {
        (error as? LocalizedError)?.errorDescription ?? fallback
    }
}
