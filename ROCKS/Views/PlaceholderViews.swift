import SwiftUI

/// Informational screen for sections whose dedicated in-app experience is not
/// available yet. Offers the official ROCKS website as the verified source.
struct PlaceholderView: View {
    let title: String
    let systemImage: String
    var officialURL: URL? = OfficialLinks.website

    @State private var presentedLink: IdentifiableURL?

    var body: some View {
        VStack(spacing: 18) {
            ContentUnavailableView(title, systemImage: systemImage, description: Text("Details for this section are available on the official ROCKS website."))

            if let officialURL {
                Button {
                    presentedLink = IdentifiableURL(url: officialURL)
                } label: {
                    Label("Visit rocksinc.org", systemImage: "globe")
                        .font(.headline)
                        .frame(maxWidth: 280, minHeight: 50)
                        .foregroundStyle(ROCKSColor.black)
                        .background(ROCKSColor.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityHint("Opens the official ROCKS website")
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ROCKSColor.background)
        .navigationTitle(title)
        .officialLinkSheet($presentedLink)
    }
}
