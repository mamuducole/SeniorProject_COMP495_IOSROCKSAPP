import SwiftUI

/// Members Directory tab: searchable list of ROCKS members.
struct MembersView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: MembersViewModel?
    @State private var path = NavigationPath()

    var body: some View {
        Group {
            if let viewModel {
                MembersDirectoryContent(viewModel: viewModel, path: $path)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ROCKSColor.background)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = MembersViewModel(environment: appState.environment)
            }
        }
    }
}

private struct MembersDirectoryContent: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: MembersViewModel
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: ROCKSTheme.spacingMD) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Members Directory")
                            .font(ROCKSFont.display)
                            .foregroundStyle(ROCKSColor.primaryText)
                        Text("Connect with leaders across the ROCKS network.")
                            .font(.subheadline)
                            .foregroundStyle(ROCKSColor.subtleText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !appState.environment.isLive {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("Demo data — connect a backend to show the real member directory.")
                                .font(.caption)
                        }
                        .foregroundStyle(ROCKSColor.goldText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ROCKSColor.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel("Demo data notice")
                    }

                    ROCKSSearchField(prompt: "Search by name, rank, or chapter", text: $viewModel.searchText)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if viewModel.filteredMembers.isEmpty && !viewModel.isLoading {
                        EmptyStateView(title: "No members found", systemImage: "person.2", message: "Try a different name or chapter.")
                            .frame(minHeight: 220)
                    } else {
                        LazyVStack(spacing: ROCKSTheme.spacingSM) {
                            ForEach(viewModel.filteredMembers) { member in
                                NavigationLink(value: member) {
                                    MemberCardView(member: member)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(ROCKSColor.background)
            .navigationBarHidden(true)
            .refreshable { await viewModel.load() }
            .navigationDestination(for: MemberProfile.self) { member in
                MemberDetailView(member: member)
            }
        }
        .task { await viewModel.load() }
    }
}

struct MemberCardView: View {
    let member: MemberProfile

    var body: some View {
        ROCKSCard {
            HStack(spacing: 12) {
                ROCKSAvatar(name: member.fullName, url: member.avatarURL, size: .md)
                VStack(alignment: .leading, spacing: 3) {
                    Text(member.fullName)
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.primaryText)
                    if !member.headline.isEmpty {
                        Text(member.headline)
                            .font(.caption)
                            .foregroundStyle(ROCKSColor.subtleText)
                            .lineLimit(1)
                    }
                    Text(member.role.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ROCKSColor.goldText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ROCKSColor.subtleText)
            }
        }
    }
}

struct MemberDetailView: View {
    let member: MemberProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ROCKSTheme.spacingMD) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient.rocksBranded
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    HStack(spacing: 16) {
                        ROCKSAvatar(name: member.fullName, url: member.avatarURL, size: .lg)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(member.fullName)
                                .font(ROCKSFont.titleSmall)
                                .foregroundStyle(.white)
                            if !member.headline.isEmpty {
                                Text(member.headline)
                                    .font(.subheadline)
                                    .foregroundStyle(ROCKSColor.onDarkText.opacity(0.85))
                            }
                            Text(member.role.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ROCKSColor.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ROCKSColor.gold, in: Capsule())
                        }
                    }
                    .padding(20)
                }

                if let bio = member.bio, !bio.isEmpty {
                    ROCKSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                                .foregroundStyle(ROCKSColor.primaryText)
                            Text(bio)
                                .font(.body)
                                .foregroundStyle(ROCKSColor.subtleText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let chapterName = member.chapterName {
                    ROCKSCard {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(ROCKSColor.goldText)
                            Text(chapterName)
                                .font(.subheadline)
                                .foregroundStyle(ROCKSColor.primaryText)
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Member")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MembersView()
        .environment(AppState.preview)
}
