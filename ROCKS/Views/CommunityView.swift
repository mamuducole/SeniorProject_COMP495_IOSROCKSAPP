import SwiftUI

/// The ROCKS Connect community board — member posts, likes, and comment discussions.
struct CommunityView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: FeedViewModel?

    var body: some View {
        Group {
            if let viewModel {
                CommunityFeedContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ROCKSColor.background)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = FeedViewModel(environment: appState.environment, currentUserID: appState.currentUser?.id, isModerator: appState.currentUser?.role == .nationalAdmin)
            }
        }
    }
}

/// Identifies the Create/Edit Post screen presentation.
enum PostComposerMode: Identifiable {
    case create
    case edit(Post)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let post): "edit-\(post.id)"
        }
    }
}

private struct CommunityFeedContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: FeedViewModel
    @State private var composerMode: PostComposerMode?
    @State private var selectedPostID: UUID?
    @State private var postPendingDeletion: Post?
    @State private var reportTarget: ReportTarget?

    private var canParticipate: Bool {
        appState.currentUser?.role.can(.participateInCommunity) ?? false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ROCKSTheme.spacingMD) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("COMMUNITY")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(ROCKSColor.goldText)
                    Text("Stay connected.")
                        .font(ROCKSFont.title)
                        .foregroundStyle(ROCKSColor.primaryText)
                    Text("Updates and conversations from the ROCKS community.")
                        .font(.subheadline)
                        .foregroundStyle(ROCKSColor.subtleText)
                    Text("All posts")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if canParticipate {
                    composerPrompt
                } else {
                    readOnlyNotice
                }
                feedContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .animation(reduceMotion ? nil : .snappy, value: viewModel.posts.map(\.id))
        }
        .background(ROCKSColor.background)
        .navigationTitle("Community Board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canParticipate {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        composerMode = .create
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(ROCKSColor.goldText)
                    }
                    .accessibilityLabel("Create post")
                }
            }
        }
        .refreshable { await viewModel.load() }
        .navigationDestination(item: $selectedPostID) { postID in
            PostDetailView(postID: postID, viewModel: viewModel, canParticipate: canParticipate)
        }
        .sheet(item: $composerMode) { mode in
            PostComposerView(mode: mode, viewModel: viewModel)
        }
        .reportDialog(target: $reportTarget, viewModel: viewModel)
        .confirmationDialog(
            "Delete this post?",
            isPresented: Binding(
                get: { postPendingDeletion != nil },
                set: { if !$0 { postPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: postPendingDeletion
        ) { post in
            Button("Delete Post", role: .destructive) {
                Task { _ = await viewModel.deletePost(post) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This permanently removes the post and its comments.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.actionErrorMessage != nil && composerMode == nil && selectedPostID == nil },
                set: { if !$0 { viewModel.actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.actionErrorMessage = nil }
        } message: {
            Text(viewModel.actionErrorMessage ?? "")
        }
        .task {
            if !viewModel.hasLoaded { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        if !viewModel.hasLoaded && viewModel.posts.isEmpty {
            if let message = viewModel.loadErrorMessage, !viewModel.isLoading {
                ErrorStateView(message: message) {
                    Task { await viewModel.load() }
                }
                .frame(minHeight: 260)
            } else {
                LoadingView()
                    .frame(minHeight: 260)
            }
        } else {
            if let message = viewModel.loadErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(ROCKSColor.badgeRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Refresh failed. \(message)")
            }

            if viewModel.posts.isEmpty {
                EmptyStateView(
                    title: "No posts yet",
                    systemImage: "text.bubble",
                    message: canParticipate
                        ? "Be the first to share an update with the ROCKS community."
                        : "Member updates will appear here."
                )
                .frame(minHeight: 260)
            } else {
                LazyVStack(spacing: ROCKSTheme.spacingMD) {
                    ForEach(viewModel.posts) { post in
                        PostCardView(
                            post: post,
                            currentUserID: viewModel.currentUserID,
                            isLikeInFlight: viewModel.likesInFlight.contains(post.id),
                            canInteract: canParticipate,
                            bodyLineLimit: 8,
                            onLike: { Task { await viewModel.toggleLike(for: post) } },
                            onComment: { selectedPostID = post.id },
                            onOpen: { selectedPostID = post.id },
                            onEdit: { composerMode = .edit(post) },
                            onDelete: { postPendingDeletion = post },
                            isModerator: viewModel.isModerator,
                            onReport: { reportTarget = .post(post.id) }
                        )
                        .opacity(viewModel.deletingPostIDs.contains(post.id) ? 0.5 : 1)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private var composerPrompt: some View {
        Button {
            composerMode = .create
        } label: {
            HStack(spacing: 12) {
                ROCKSAvatar(
                    name: appState.currentMember?.fullName ?? "ROCKS Member",
                    url: appState.currentMember?.avatarURL,
                    size: .md
                )
                Text("Share an update with the community\u{2026}")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(ROCKSColor.insetBackground, in: Capsule())
                Image(systemName: "square.and.pencil")
                    .font(.headline)
                    .foregroundStyle(ROCKSColor.goldText)
            }
            .padding(ROCKSTheme.cardPadding)
            .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous)
                    .stroke(ROCKSColor.goldStroke, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create post")
        .accessibilityHint("Opens the Create Post screen")
    }

    private var readOnlyNotice: some View {
        Label("Only approved members can post, like, comment, and report.", systemImage: "lock.fill")
            .font(.footnote)
            .foregroundStyle(ROCKSColor.subtleText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(ROCKSTheme.cardPadding)
            .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous))
    }
}

// MARK: - Post Card

struct PostCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let post: Post
    var currentUserID: UUID?
    var isLikeInFlight = false
    var canInteract = true
    var bodyLineLimit: Int?
    let onLike: () -> Void
    let onComment: () -> Void
    var onOpen: (() -> Void)?
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var isModerator = false
    var onReport: (() -> Void)?

    private var canEdit: Bool { onEdit != nil && post.canEdit(as: currentUserID) }
    private var canDelete: Bool { onDelete != nil && (post.canDelete(as: currentUserID) || isModerator) }
    private var canReport: Bool {
        onReport != nil && canInteract && currentUserID != nil && post.author.id != currentUserID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if post.kind.isOfficial {
                Label(post.kind.badgeTitle, systemImage: "megaphone.fill")
                    .font(.caption.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(ROCKSColor.goldText)
            }

            header

            Group {
                Text(post.body)
                    .font(.body)
                    .foregroundStyle(ROCKSColor.primaryText)
                    .lineLimit(bodyLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                if post.imageName != nil || post.imageURL != nil {
                    // Overlay keeps a fill-scaled image from widening the card beyond the screen.
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .overlay {
                            ROCKSImage(url: post.imageURL, assetName: post.imageName, radius: 14)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onOpen?() }
            .accessibilityAddTraits(onOpen == nil ? [] : .isButton)
            .accessibilityHint(onOpen == nil ? "" : "Opens the post and its comments")

            Divider().overlay(ROCKSColor.divider)

            actionBar
        }
        .padding(ROCKSTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous)
                .stroke(post.kind.isOfficial ? ROCKSColor.goldStroke : ROCKSColor.divider, lineWidth: 1)
        }
        .shadow(color: ROCKSTheme.cardShadow, radius: 10, x: 0, y: 4)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            ROCKSAvatar(name: post.author.fullName, url: post.author.avatarURL, size: .md)
            VStack(alignment: .leading, spacing: 2) {
                Text(post.author.fullName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                if !post.author.headline.isEmpty {
                    Text(post.author.headline)
                        .font(.caption)
                        .foregroundStyle(ROCKSColor.subtleText)
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(post.createdAt.rocksRelative)
                    if post.editedAt != nil {
                        Text("\u{2022} Edited")
                    }
                }
                .font(.caption2)
                .foregroundStyle(ROCKSColor.subtleText)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(timestampAccessibilityLabel)
            }
            Spacer(minLength: 4)
            if canEdit || canDelete || canReport {
                Menu {
                    if canEdit, let onEdit {
                        Button("Edit Post", systemImage: "pencil", action: onEdit)
                    }
                    if canReport, let onReport {
                        Button("Report Post", systemImage: "flag", action: onReport)
                    }
                    if canDelete, let onDelete {
                        Button(post.canDelete(as: currentUserID) ? "Delete Post" : "Remove Post (Moderator)",
                               systemImage: "trash", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.subtleText)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Post options")
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 22) {
            Button(action: onLike) {
                HStack(spacing: 6) {
                    if reduceMotion {
                        Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                    } else {
                        Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                            .symbolEffect(.bounce, value: post.isLikedByCurrentUser)
                    }
                    Text("\(post.likeCount)")
                        .contentTransition(reduceMotion ? .identity : .numericText(value: Double(post.likeCount)))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(post.isLikedByCurrentUser ? ROCKSColor.goldText : ROCKSColor.subtleText)
                .animation(reduceMotion ? nil : .snappy, value: post.likeCount)
            }
            .buttonStyle(.plain)
            .disabled(!canInteract || isLikeInFlight)
            .accessibilityLabel(post.isLikedByCurrentUser ? "Unlike" : "Like")
            .accessibilityValue("\(post.likeCount) \(post.likeCount == 1 ? "like" : "likes")")

            Button(action: onComment) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                    Text("\(post.commentCount)")
                        .contentTransition(.numericText(value: Double(post.commentCount)))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ROCKSColor.subtleText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comments")
            .accessibilityValue("\(post.commentCount) \(post.commentCount == 1 ? "comment" : "comments")")

            Spacer()
        }
    }

    private var timestampAccessibilityLabel: String {
        let posted = "Posted \(post.createdAt.formatted(date: .abbreviated, time: .shortened))"
        return post.editedAt == nil ? posted : posted + ", edited"
    }
}

// MARK: - Create / Edit Post

struct PostComposerView: View {
    let mode: PostComposerMode
    @Bindable var viewModel: FeedViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var editText = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var text: Binding<String> {
        isEditing ? $editText : $viewModel.draftBody
    }

    private var trimmedCount: Int {
        text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var isOverLimit: Bool { trimmedCount > Post.maxBodyLength }

    private var canSubmit: Bool {
        guard trimmedCount > 0, !isOverLimit, !viewModel.isPosting else { return false }
        if case .edit(let post) = mode {
            return editText.trimmingCharacters(in: .whitespacesAndNewlines) != post.body
        }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ROCKSAvatar(
                        name: appState.currentMember?.fullName ?? "ROCKS Member",
                        url: appState.currentMember?.avatarURL,
                        size: .md
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.currentMember?.fullName ?? "ROCKS Member")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ROCKSColor.primaryText)
                        Text("Visible to signed-in ROCKS members")
                            .font(.caption)
                            .foregroundStyle(ROCKSColor.subtleText)
                    }
                }

                ZStack(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text("What would you like to share with the community?")
                            .font(.body)
                            .foregroundStyle(ROCKSColor.subtleText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: text)
                        .font(.body)
                        .foregroundStyle(ROCKSColor.primaryText)
                        .tint(ROCKSColor.goldText)
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                        .accessibilityLabel("Post text")
                }
                .padding(10)
                .frame(maxHeight: .infinity)
                .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isFocused ? ROCKSColor.goldStroke : ROCKSColor.divider, lineWidth: 1)
                }

                HStack(alignment: .firstTextBaseline) {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(ROCKSColor.badgeRed)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                    Spacer()
                    Text("\(trimmedCount)/\(Post.maxBodyLength)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isOverLimit ? ROCKSColor.badgeRed : ROCKSColor.subtleText)
                        .accessibilityLabel("\(trimmedCount) of \(Post.maxBodyLength) characters")
                }
            }
            .padding(20)
            .background(ROCKSColor.background)
            .navigationTitle(isEditing ? "Edit Post" : "Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isPosting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isPosting {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Save" : "Post") {
                            Task { await submit() }
                        }
                        .fontWeight(.semibold)
                        .tint(ROCKSColor.goldText)
                        .disabled(!canSubmit)
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isPosting)
            .animation(.easeInOut(duration: 0.2), value: errorMessage)
        }
        .onAppear {
            if case .edit(let post) = mode { editText = post.body }
            isFocused = true
        }
        .onDisappear {
            viewModel.actionErrorMessage = nil
        }
    }

    private func submit() async {
        errorMessage = nil
        let succeeded: Bool
        switch mode {
        case .create:
            succeeded = await viewModel.publishDraft()
        case .edit(let post):
            succeeded = await viewModel.updatePost(post, body: editText)
        }
        if succeeded {
            dismiss()
        } else {
            errorMessage = viewModel.actionErrorMessage ?? "Something went wrong. Please try again."
            viewModel.actionErrorMessage = nil
        }
    }
}

// MARK: - Post Detail

struct PostDetailView: View {
    let postID: UUID
    @Bindable var viewModel: FeedViewModel
    let canParticipate: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""
    @State private var isSending = false
    @State private var composerMode: PostComposerMode?
    @State private var isConfirmingPostDeletion = false
    @State private var commentPendingDeletion: PostComment?
    @State private var reportTarget: ReportTarget?
    @FocusState private var isCommentFieldFocused: Bool

    private var post: Post? { viewModel.post(id: postID) }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if let post {
                content(for: post)
            } else {
                EmptyStateView(
                    title: "Post unavailable",
                    systemImage: "text.bubble",
                    message: "This post may have been deleted."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ROCKSColor.background)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refreshPost(id: postID) }
    }

    private func content(for post: Post) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: ROCKSTheme.spacingMD) {
                    PostCardView(
                        post: post,
                        currentUserID: viewModel.currentUserID,
                        isLikeInFlight: viewModel.likesInFlight.contains(post.id),
                        canInteract: canParticipate,
                        onLike: { Task { await viewModel.toggleLike(for: post) } },
                        onComment: { isCommentFieldFocused = true },
                        onEdit: { composerMode = .edit(post) },
                        onDelete: { isConfirmingPostDeletion = true },
                        isModerator: viewModel.isModerator,
                        onReport: { reportTarget = .post(post.id) }
                    )

                    Text("Posted \(post.createdAt.formatted(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(ROCKSColor.subtleText)
                        .padding(.horizontal, 4)

                    Text(post.commentCount == 1 ? "1 Comment" : "\(post.commentCount) Comments")
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.primaryText)
                        .padding(.horizontal, 4)

                    if post.comments.isEmpty {
                        EmptyStateView(
                            title: "No comments yet",
                            systemImage: "bubble.right",
                            message: canParticipate ? "Start the conversation." : "Comments from members will appear here."
                        )
                        .frame(minHeight: 180)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(post.comments) { comment in
                                CommentRowView(
                                    comment: comment,
                                    canDelete: viewModel.canDelete(comment),
                                    canReport: canParticipate && comment.author.id != viewModel.currentUserID,
                                    isDeleting: viewModel.deletingCommentIDs.contains(comment.id),
                                    onDelete: { commentPendingDeletion = comment },
                                    onReport: { reportTarget = .comment(comment.id) }
                                )
                                .id(comment.id)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .animation(reduceMotion ? nil : .snappy, value: post.comments.map(\.id))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ROCKSColor.background)
            .refreshable { await viewModel.refreshPost(id: postID) }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if canParticipate {
                    commentBar(for: post, proxy: proxy)
                }
            }
        }
        .sheet(item: $composerMode) { mode in
            PostComposerView(mode: mode, viewModel: viewModel)
        }
        .reportDialog(target: $reportTarget, viewModel: viewModel)
        .confirmationDialog("Delete this post?", isPresented: $isConfirmingPostDeletion, titleVisibility: .visible) {
            Button("Delete Post", role: .destructive) {
                Task {
                    if await viewModel.deletePost(post) { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the post and its comments.")
        }
        .confirmationDialog(
            "Delete this comment?",
            isPresented: Binding(
                get: { commentPendingDeletion != nil },
                set: { if !$0 { commentPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: commentPendingDeletion
        ) { comment in
            Button("Delete Comment", role: .destructive) {
                Task { _ = await viewModel.deleteComment(comment, from: post) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.actionErrorMessage != nil && composerMode == nil },
                set: { if !$0 { viewModel.actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.actionErrorMessage = nil }
        } message: {
            Text(viewModel.actionErrorMessage ?? "")
        }
    }

    private func commentBar(for post: Post, proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Add a comment\u{2026}", text: $draft, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...4)
                .tint(ROCKSColor.goldText)
                .focused($isCommentFieldFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ROCKSColor.insetBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityLabel("Comment text")

            Button {
                send(to: post, proxy: proxy)
            } label: {
                Group {
                    if isSending {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(ROCKSColor.goldText)
                    }
                }
                .frame(width: 36, height: 36)
            }
            .disabled(trimmedDraft.isEmpty || trimmedDraft.count > PostComment.maxBodyLength || isSending)
            .opacity(trimmedDraft.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Send comment")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ROCKSColor.cardBackground)
        .overlay(alignment: .top) {
            Divider().overlay(ROCKSColor.divider)
        }
    }

    private func send(to post: Post, proxy: ScrollViewProxy) {
        guard !isSending else { return }
        isSending = true
        Task {
            let sent = await viewModel.addComment(draft, to: post)
            if sent {
                draft = ""
                if let last = viewModel.post(id: post.id)?.comments.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            isSending = false
        }
    }
}

private struct CommentRowView: View {
    let comment: PostComment
    let canDelete: Bool
    let canReport: Bool
    let isDeleting: Bool
    let onDelete: () -> Void
    let onReport: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ROCKSAvatar(name: comment.author.fullName, url: comment.author.avatarURL, size: .sm)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(comment.author.fullName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ROCKSColor.primaryText)
                    Text(comment.createdAt.rocksRelative)
                        .font(.caption2)
                        .foregroundStyle(ROCKSColor.subtleText)
                        .accessibilityLabel("Commented \(comment.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Spacer(minLength: 0)
                    if canDelete || canReport {
                        Menu {
                            if canReport {
                                Button("Report Comment", systemImage: "flag", action: onReport)
                            }
                            if canDelete {
                                Button("Delete Comment", systemImage: "trash", role: .destructive, action: onDelete)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ROCKSColor.subtleText)
                                .frame(width: 28, height: 20)
                                .contentShape(Rectangle())
                        }
                        .disabled(isDeleting)
                        .accessibilityLabel("Comment options")
                    }
                }
                if !comment.author.headline.isEmpty {
                    Text(comment.author.headline)
                        .font(.caption2)
                        .foregroundStyle(ROCKSColor.subtleText)
                        .lineLimit(1)
                }
                Text(comment.body)
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ROCKSColor.divider, lineWidth: 1)
        }
        .opacity(isDeleting ? 0.5 : 1)
    }
}

private extension View {
    /// Reason picker for reporting a post or comment, plus a confirmation when the report is sent.
    func reportDialog(target: Binding<ReportTarget?>, viewModel: FeedViewModel) -> some View {
        self
            .confirmationDialog(
                "Why are you reporting this?",
                isPresented: Binding(get: { target.wrappedValue != nil }, set: { if !$0 { target.wrappedValue = nil } }),
                titleVisibility: .visible,
                presenting: target.wrappedValue
            ) { reported in
                ForEach(ReportReason.allCases) { reason in
                    Button(reason.title) {
                        Task { await viewModel.report(reported, reason: reason) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Reports are reviewed by ROCKS administrators.")
            }
            .alert(
                "Report sent",
                isPresented: Binding(
                    get: { viewModel.noticeMessage != nil },
                    set: { if !$0 { viewModel.noticeMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.noticeMessage = nil }
            } message: {
                Text(viewModel.noticeMessage ?? "")
            }
    }
}

#Preview("Light") {
    NavigationStack { CommunityView() }
        .environment(AppState.preview)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack { CommunityView() }
        .environment(AppState.preview)
        .preferredColorScheme(.dark)
}
