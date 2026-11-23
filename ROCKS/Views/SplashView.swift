import SwiftUI

/// Branded launch screen: emblem, wordmark, and tagline over the deep navy gradient.
struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient.rocksBranded
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Image("rocksLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180)
                    .accessibilityLabel("The ROCKS, Inc. emblem")

                VStack(spacing: 6) {
                    Text("THE ROCKS, INC.")
                        .font(.title3.weight(.bold))
                        .tracking(3)
                        .foregroundStyle(ROCKSColor.onDarkText)
                    Text("Service \u{2022} Mentorship \u{2022} Leadership")
                        .font(.subheadline.weight(.medium))
                        .tracking(1.2)
                        .foregroundStyle(ROCKSColor.goldLight)
                }

                Rectangle()
                    .fill(ROCKSColor.gold.opacity(0.7))
                    .frame(width: 64, height: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SplashView()
}
