import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let recoveryState = appState.passwordRecoveryState {
                PasswordRecoveryView(state: recoveryState)
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else if appState.isRestoringSession {
                ProgressView("Restoring session")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ROCKSColor.background)
            } else if !appState.isAuthenticated {
                LoginView(authService: appState.authService)
            } else if let user = appState.currentUser, !user.hasMemberAccess {
                MembershipStatusView(user: user)
            } else {
                MainTabView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            if appState.isDemoUser {
                DemoModeBanner()
            }
            TabView(selection: Bindable(appState).selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(AppTab.home)
                ExploreMenuView()
                    .tabItem { Label("Connect", systemImage: "person.2") }
                    .tag(AppTab.connect)
                EventListView()
                    .tabItem { Label("Events", systemImage: "calendar") }
                    .tag(AppTab.events)
                ProgramsView()
                    .tabItem { Label("Learn", systemImage: "book") }
                    .tag(AppTab.learn)
                ProfileView()
                    .tabItem { Label("You", systemImage: "person") }
                    .tag(AppTab.you)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .tint(ROCKSColor.goldText)
            .toolbarBackground(.regularMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        }
    }
}

/// Shown to signed-in accounts that are not approved members. The server independently
/// denies member data to these accounts; this screen only explains the state.
struct MembershipStatusView: View {
    @Environment(AppState.self) private var appState
    let user: AuthUser
    @State private var isWorking = false
    @State private var confirmDeletion = false
    @State private var message: String?
    @State private var presentedLink: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image("rocksLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .accessibilityLabel("The ROCKS, Inc. emblem")
                VStack(spacing: 8) {
                    Text(user.membershipStatus.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(ROCKSColor.primaryText)
                        .multilineTextAlignment(.center)
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(ROCKSColor.subtleText)
                        .multilineTextAlignment(.center)
                    Text(user.email)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ROCKSColor.goldText)
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(ROCKSColor.badgeRed)
                        .multilineTextAlignment(.center)
                }
                Button {
                    Task {
                        isWorking = true
                        await appState.refreshAccess()
                        isWorking = false
                    }
                } label: {
                    Group {
                        if isWorking { ProgressView().tint(ROCKSColor.black) } else { Text("Check Status").font(.headline) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(ROCKSColor.black)
                    .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isWorking)
                VStack(spacing: 10) {
                    OfficialLinkRow(title: "Join The ROCKS", subtitle: "Official new member sign-up and dues", systemImage: "person.badge.plus") {
                        presentedLink = IdentifiableURL(url: OfficialLinks.joinMembership)
                    }
                    OfficialLinkRow(title: "Renew Membership", subtitle: "Sign in to your official member account", systemImage: "arrow.triangle.2.circlepath") {
                        presentedLink = IdentifiableURL(url: OfficialLinks.memberLogin)
                    }
                    OfficialLinkRow(title: "Contact The ROCKS", subtitle: "Questions about your membership", systemImage: "envelope") {
                        presentedLink = IdentifiableURL(url: OfficialLinks.contact)
                    }
                }
                Button("Sign Out") { Task { await appState.signOut() } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ROCKSColor.goldText)
                    .frame(minHeight: 44)
                    .disabled(isWorking)
                Button("Delete Account", role: .destructive) { confirmDeletion = true }
                    .font(.subheadline)
                    .frame(minHeight: 44)
                    .disabled(isWorking)
            }
            .padding(24)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .background(ROCKSColor.background)
        .officialLinkSheet($presentedLink)
        .confirmationDialog("Delete your account?", isPresented: $confirmDeletion, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Task {
                    isWorking = true
                    message = await appState.deleteAccount()
                    isWorking = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your ROCKS Connect account and application.")
        }
    }

    private var explanation: String {
        switch user.membershipStatus {
        case .pending, .approved:
            "Thank you for registering. A ROCKS administrator will review your membership. Member features become available after approval."
        case .declined:
            "Your application was not approved. Contact The ROCKS, Inc. if you believe this is a mistake."
        case .suspended:
            "Your access to member features is suspended. Contact The ROCKS, Inc. for assistance."
        }
    }
}

private struct DemoModeBanner: View {
    var body: some View {
        Label("DEMO · Sample data; changes stay on this device", systemImage: "testtube.2")
            .font(.caption.weight(.semibold))
            .foregroundStyle(ROCKSColor.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(ROCKSColor.gold)
            .accessibilityLabel("Demo mode. Sample data; changes stay on this device.")
    }
}

#Preview {
    RootView()
        .environment(AppState.preview)
}
