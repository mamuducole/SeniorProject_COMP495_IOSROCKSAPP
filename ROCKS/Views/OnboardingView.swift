import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var page = 0

    private let pages = [
        ("Welcome to The ROCKS, Inc.", "A community shaping talent through mentorship.", "figure.2.and.child.holdinghands"),
        ("Mentorship & Leadership", "Build stronger careers and lead with purpose.", "person.2.fill"),
        ("Find Your Chapter", "Connect with a local community built around service.", "mappin.and.ellipse"),
        ("Events & Development", "Discover experiences that help you grow.", "calendar.badge.plus"),
        ("Join the Community", "Stay connected to the people and opportunities that move you forward.", "arrow.right.circle.fill")
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image("rocksLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 110)
                .accessibilityLabel("The ROCKS, Inc. emblem")
            Image(systemName: pages[page].2)
                .font(.system(size: 68))
                .foregroundStyle(ROCKSColor.goldText)
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(pages[page].0)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ROCKSColor.primaryText)
                Text(pages[page].1)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            Spacer()
            HStack {
                Button("Skip") { appState.completeOnboarding() }
                    .frame(minWidth: 72, minHeight: 44)
                Spacer()
                Button(page == pages.count - 1 ? "Get Started" : "Next") {
                    if page == pages.count - 1 {
                        appState.completeOnboarding()
                    } else {
                        page += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ROCKSColor.gold)
                .foregroundStyle(ROCKSColor.black)
                .frame(minHeight: 44)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .animation(.easeInOut, value: page)
    }
}
