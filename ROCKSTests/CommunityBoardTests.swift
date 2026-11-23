import XCTest
@testable import ROCKS

@MainActor
final class CommunityBoardTests: XCTestCase {
    private let me = MemberProfile.demo

    private func makeViewModel() async -> FeedViewModel {
        let viewModel = FeedViewModel(environment: .preview, currentUserID: me.id)
        await viewModel.load()
        return viewModel
    }

    private func publish(_ body: String, in viewModel: FeedViewModel) async -> Post? {
        viewModel.draftBody = body
        guard await viewModel.publishDraft() else { return nil }
        return viewModel.posts.first
    }

    func testLikeThenUnlikeRestoresCountAndRepeatedLikesDoNotDuplicate() async throws {
        let viewModel = await makeViewModel()
        let post = try XCTUnwrap(viewModel.posts.first { !$0.isLikedByCurrentUser })
        let original = post.likeCount

        await viewModel.toggleLike(for: post)
        XCTAssertEqual(viewModel.post(id: post.id)?.likeCount, original + 1)

        let repository = MockFeedRepository()
        try await repository.setLiked(postID: post.id, liked: true)
        try await repository.setLiked(postID: post.id, liked: true)
        let stored = try await repository.fetchPost(id: post.id)
        XCTAssertEqual(stored?.likeCount, original + 1, "A second like must not double count")

        let likedPost = try XCTUnwrap(viewModel.post(id: post.id))
        await viewModel.toggleLike(for: likedPost)
        XCTAssertEqual(viewModel.post(id: post.id)?.likeCount, original)
        XCTAssertEqual(viewModel.post(id: post.id)?.isLikedByCurrentUser, false)
    }

    func testCommentIsDisplayedOnItsPostAndAuthorCanDeleteIt() async throws {
        let viewModel = await makeViewModel()
        let post = try XCTUnwrap(viewModel.posts.first)
        let countBefore = post.commentCount

        let added = await viewModel.addComment("  Great work, team.  ", to: post)

        XCTAssertTrue(added)
        let comment = try XCTUnwrap(viewModel.post(id: post.id)?.comments.last)
        XCTAssertEqual(comment.body, "Great work, team.")
        XCTAssertEqual(comment.author.id, me.id)
        XCTAssertEqual(viewModel.post(id: post.id)?.commentCount, countBefore + 1)

        let deleted = await viewModel.deleteComment(comment, from: post)

        XCTAssertTrue(deleted)
        XCTAssertEqual(viewModel.post(id: post.id)?.commentCount, countBefore)
    }

    func testAuthorCanEditAndDeleteOwnPost() async throws {
        let viewModel = await makeViewModel()
        let published = await publish("First draft", in: viewModel)
        let post = try XCTUnwrap(published)
        XCTAssertTrue(post.canEdit(as: me.id))

        let edited = await viewModel.updatePost(post, body: "Revised update")

        XCTAssertTrue(edited)
        XCTAssertEqual(viewModel.post(id: post.id)?.body, "Revised update")
        XCTAssertNotNil(viewModel.post(id: post.id)?.editedAt)

        let editedPost = try XCTUnwrap(viewModel.post(id: post.id))
        let deleted = await viewModel.deletePost(editedPost)

        XCTAssertTrue(deleted)
        XCTAssertNil(viewModel.post(id: post.id))
    }

    func testMemberCannotEditOrDeleteAnotherMembersContent() async throws {
        let viewModel = await makeViewModel()
        let othersPost = try XCTUnwrap(viewModel.posts.first { $0.author.id != me.id && !$0.comments.isEmpty })
        let othersComment = try XCTUnwrap(othersPost.comments.first)

        XCTAssertFalse(othersPost.canEdit(as: me.id))
        XCTAssertFalse(othersPost.canDelete(as: me.id))
        XCTAssertFalse(othersComment.canDelete(as: me.id))

        let edited = await viewModel.updatePost(othersPost, body: "Hijacked")
        let deletedPost = await viewModel.deletePost(othersPost)
        let deletedComment = await viewModel.deleteComment(othersComment, from: othersPost)

        XCTAssertFalse(edited)
        XCTAssertFalse(deletedPost)
        XCTAssertFalse(deletedComment)
        XCTAssertEqual(viewModel.post(id: othersPost.id)?.body, othersPost.body)
        XCTAssertEqual(viewModel.post(id: othersPost.id)?.commentCount, othersPost.commentCount)

        // The repository enforces ownership too, mirroring RLS, even if the UI check is bypassed.
        let repository = MockFeedRepository()
        do {
            try await repository.deletePost(id: othersPost.id)
            XCTFail("Deleting another member's post must fail")
        } catch AppError.unauthorized {}
        do {
            try await repository.deleteComment(id: othersComment.id, postID: othersPost.id)
            XCTFail("Deleting another member's comment must fail")
        } catch AppError.unauthorized {}
        do {
            _ = try await repository.updatePost(id: othersPost.id, body: "Hijacked")
            XCTFail("Editing another member's post must fail")
        } catch AppError.unauthorized {}
    }

    func testBackendFailuresAreSurfacedWithoutSimulatingSuccess() async {
        let viewModel = FeedViewModel(environment: .makeUnavailable(configuration: .preview), currentUserID: me.id)

        await viewModel.load()

        XCTAssertFalse(viewModel.hasLoaded)
        XCTAssertNotNil(viewModel.loadErrorMessage)
        XCTAssertTrue(viewModel.posts.isEmpty)

        viewModel.draftBody = "This should not appear"
        let published = await viewModel.publishDraft()

        XCTAssertFalse(published)
        XCTAssertTrue(viewModel.posts.isEmpty)
        XCTAssertEqual(viewModel.draftBody, "This should not appear", "The draft is kept so the member can retry")
        XCTAssertNotNil(viewModel.actionErrorMessage)
    }

    func testPostValidationRejectsEmptyAndOverlongText() async {
        let viewModel = await makeViewModel()
        let countBefore = viewModel.posts.count

        viewModel.draftBody = "   \n "
        let emptyPublished = await viewModel.publishDraft()
        viewModel.draftBody = String(repeating: "a", count: Post.maxBodyLength + 1)
        let longPublished = await viewModel.publishDraft()

        XCTAssertFalse(emptyPublished)
        XCTAssertFalse(longPublished)
        XCTAssertEqual(viewModel.posts.count, countBefore)
    }

    func testRefreshReloadsFeedAndGuestsCannotParticipate() async {
        let viewModel = await makeViewModel()
        let initialCount = viewModel.posts.count

        await viewModel.load()

        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertNil(viewModel.loadErrorMessage)
        XCTAssertEqual(viewModel.posts.count, initialCount)
        XCTAssertFalse(AppRole.guest.can(.participateInCommunity))
        XCTAssertTrue(AppRole.member.can(.participateInCommunity))
    }

    func testReportingSendsOnceAndConfirmsWithoutFalseSuccess() async throws {
        let viewModel = await makeViewModel()
        let post = try XCTUnwrap(viewModel.posts.first { $0.author.id != me.id })

        await viewModel.report(.post(post.id), reason: .spam)
        XCTAssertNotNil(viewModel.noticeMessage)
        XCTAssertNil(viewModel.actionErrorMessage)

        viewModel.noticeMessage = nil
        await viewModel.report(.post(post.id), reason: .other)
        XCTAssertNil(viewModel.noticeMessage, "A rejected report must not show a success message")
        XCTAssertNotNil(viewModel.actionErrorMessage)
    }

    func testOnlyModeratorsMayRemoveOtherMembersContent() async throws {
        let member = await makeViewModel()
        let othersPost = try XCTUnwrap(member.posts.first { $0.author.id != me.id })
        XCTAssertFalse(member.canDelete(othersPost))
        let deleted = await member.deletePost(othersPost)
        XCTAssertFalse(deleted)
        XCTAssertNotNil(member.post(id: othersPost.id))

        let moderator = FeedViewModel(environment: .preview, currentUserID: me.id, isModerator: true)
        await moderator.load()
        XCTAssertTrue(moderator.canDelete(othersPost))
        let comment = try XCTUnwrap(moderator.posts.flatMap(\.comments).first { $0.author.id != me.id })
        XCTAssertTrue(moderator.canDelete(comment))
    }
}
