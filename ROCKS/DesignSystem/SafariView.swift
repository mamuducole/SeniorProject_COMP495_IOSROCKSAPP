import SafariServices
import SwiftUI

/// Wraps a URL so it can drive `.sheet(item:)` presentations.
struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// In-app Safari browser for opening verified official links without leaving
/// the app. Authentication and payments remain on the official website.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(ROCKSColor.gold)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

enum OfficialLinkPolicy {
    /// `SFSafariViewController` raises an uncatchable exception for non-HTTP URLs, and
    /// membership and payment pages must be encrypted, so only HTTPS URLs with a host open.
    static func canOpen(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && !(url.host ?? "").isEmpty
            && url.user == nil && url.password == nil
    }
}

extension View {
    /// Presents verified official links in an in-app Safari sheet. Users return with Done.
    func officialLinkSheet(_ item: Binding<IdentifiableURL?>) -> some View {
        sheet(item: item) { identifiable in
            if OfficialLinkPolicy.canOpen(identifiable.url) {
                SafariView(url: identifiable.url)
                    .ignoresSafeArea()
            } else {
                UnavailableLinkView { item.wrappedValue = nil }
            }
        }
    }
}

private struct UnavailableLinkView: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: "Link unavailable",
                systemImage: "exclamationmark.triangle",
                message: "This link cannot be opened securely. Please visit rocksinc.org or contact The ROCKS, Inc."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ROCKSColor.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose).tint(ROCKSColor.goldText)
                }
            }
        }
    }
}

/// A full-width branded row button that opens an official link.
struct OfficialLinkRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let action: () -> Void

    init(title: String, subtitle: String? = nil, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(ROCKSColor.goldText)
                    .frame(width: 40, height: 40)
                    .background(ROCKSColor.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.primaryText)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(ROCKSColor.subtleText)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.body)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subtitle.map { "\(title). \($0)" } ?? title)
        .accessibilityHint("Opens the official ROCKS website")
    }
}
