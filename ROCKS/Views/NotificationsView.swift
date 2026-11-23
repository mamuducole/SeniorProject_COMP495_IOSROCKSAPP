import SwiftUI

/// Notification center pushed from the dashboard bell.
struct NotificationsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: NotificationsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                NotificationsContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ROCKSColor.background)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = NotificationsViewModel(environment: appState.environment)
            }
        }
    }
}

private struct NotificationsContent: View {
    @Environment(AppState.self) private var appState
    let viewModel: NotificationsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: ROCKSTheme.spacingSM) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.notifications.isEmpty && !viewModel.isLoading {
                    EmptyStateView(title: "All caught up", systemImage: "bell.slash", message: "New announcements, events, and mentorship updates will appear here.")
                        .frame(minHeight: 260)
                } else {
                    ForEach(viewModel.notifications) { notification in
                        notificationRow(notification)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.unreadCount > 0 {
                    Button("Mark all read") {
                        Task { await viewModel.markAllRead() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ROCKSColor.goldText)
                }
            }
        }
        .task { await viewModel.load() }
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        Button {
            Task { await viewModel.markRead(notification) }
            if let route = notification.route {
                appState.pendingDeepLink = route
                appState.selectTab(for: route)
                dismiss()
            }
        } label: {
            ROCKSCard {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(notification.isRead ? ROCKSColor.divider : ROCKSColor.gold)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(notification.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ROCKSColor.primaryText)
                            Spacer()
                            Text(notification.createdAt.rocksRelative)
                                .font(.caption)
                                .foregroundStyle(ROCKSColor.subtleText)
                        }
                        if let body = notification.body {
                            Text(body)
                                .font(.caption)
                                .foregroundStyle(ROCKSColor.subtleText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .opacity(notification.isRead ? 0.7 : 1)
        }
        .buttonStyle(.plain)
    }
}
