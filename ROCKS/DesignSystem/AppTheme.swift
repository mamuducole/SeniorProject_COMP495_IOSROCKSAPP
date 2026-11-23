import SwiftUI

enum ROCKSColor {
    static let black = Color(red: 0.06, green: 0.06, blue: 0.06)
    static let charcoal = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let surfaceDark = Color(red: 0.14, green: 0.14, blue: 0.15)
    static let gold = Color(red: 0.79, green: 0.64, blue: 0.15)
    static let goldLight = Color(red: 0.90, green: 0.78, blue: 0.36)
    static let goldText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.90, green: 0.78, blue: 0.36, alpha: 1)
            : UIColor(red: 0.43, green: 0.32, blue: 0.02, alpha: 1)
    })
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.055, blue: 0.06, alpha: 1)
            : UIColor(red: 0.969, green: 0.961, blue: 0.941, alpha: 1)
    })
    static let cardBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor.white
    })
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let subtleText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.72, blue: 0.73, alpha: 1)
            : UIColor(red: 0.40, green: 0.40, blue: 0.41, alpha: 1)
    })
    static let onDarkText = Color.white
    static let divider = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.19, green: 0.19, blue: 0.20, alpha: 1)
            : UIColor(red: 0.90, green: 0.89, blue: 0.86, alpha: 1)
    })
    static let navy = black
    static let goldStroke = gold.opacity(0.45)
    static let badgeRed = Color(uiColor: .systemRed)
    static let insetBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
            : UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1)
    })
    static let ochre = gold
    static let mist = background
    static let ink = Color.primary
}

enum ROCKSTheme {
    static let cornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 18
    static let spacingSM: CGFloat = 10
    static let spacingMD: CGFloat = 18
    static let spacingLG: CGFloat = 26
    static let cardShadow = Color.black.opacity(0.08)
}

enum ROCKSFont {
    static let display = Font.largeTitle.weight(.bold)
    static let title = Font.title.weight(.bold)
    static let titleSmall = Font.title2.weight(.bold)
}

extension LinearGradient {
    static let rocksBranded = LinearGradient(
        colors: [ROCKSColor.black, ROCKSColor.charcoal, ROCKSColor.surfaceDark],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let rocksPhotoScrim = LinearGradient(
        colors: [.clear, ROCKSColor.black.opacity(0.82)],
        startPoint: .top, endPoint: .bottom
    )
}

struct ROCKSCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(ROCKSTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius, style: .continuous)
                    .stroke(ROCKSColor.divider, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct ROCKSSectionHeader: View {
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ROCKSColor.goldText)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ROCKSImage: View {
    let url: URL?
    let assetName: String?
    let radius: CGFloat

    var body: some View {
        if url == nil, let assetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: radius))
        } else {
            ROCKSRemoteImage(url: url, radius: radius)
        }
    }
}

struct ROCKSRemoteImage: View {
    let url: URL?
    let radius: CGFloat
    let contentMode: ContentMode
    let placeholderSystemImage: String

    init(url: URL?, radius: CGFloat = 20, contentMode: ContentMode = .fill, placeholderSystemImage: String = "photo") {
        self.url = url
        self.radius = radius
        self.contentMode = contentMode
        self.placeholderSystemImage = placeholderSystemImage
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(LinearGradient(gradient: Gradient(colors: [ROCKSColor.charcoal, ROCKSColor.black]), startPoint: .top, endPoint: .bottom))
                    .overlay(Image(systemName: placeholderSystemImage).foregroundStyle(ROCKSColor.goldLight))
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                Rectangle()
                    .fill(LinearGradient(gradient: Gradient(colors: [ROCKSColor.charcoal, ROCKSColor.black]), startPoint: .top, endPoint: .bottom))
                    .overlay(Image(systemName: "photo.on.rectangle.angled").foregroundStyle(ROCKSColor.goldLight))
            @unknown default:
                Rectangle().fill(ROCKSColor.charcoal)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct ROCKSStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(ROCKSColor.goldLight)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(ROCKSColor.onDarkText)
            Text(label)
                .font(.caption)
                .foregroundStyle(ROCKSColor.onDarkText.opacity(0.82))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(ROCKSColor.charcoal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.gold.opacity(0.45), lineWidth: 1))
    }
}
