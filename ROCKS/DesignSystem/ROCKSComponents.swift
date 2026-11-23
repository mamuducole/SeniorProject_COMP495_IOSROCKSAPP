import SwiftUI

// MARK: - Logo Header
// The official emblem, used on the menu, splash, profile, and branded cards.

struct ROCKSLogoHeader: View {
    enum Size {
        case large, compact

        var logoHeight: CGFloat {
            switch self {
            case .large: 44
            case .compact: 30
            }
        }
    }

    var size: Size = .compact
    var subtitle: String? = nil
    var showsTagline = false

    var body: some View {
        HStack(spacing: 12) {
            Image("rocksLogo")
                .resizable()
                .scaledToFit()
                .frame(height: size.logoHeight)
                .accessibilityLabel("The ROCKS, Inc. emblem")
            if showsTagline {
                VStack(alignment: .leading, spacing: 2) {
                    Text("THE ROCKS, INC.")
                        .font(.caption.weight(.bold))
                        .tracking(1.6)
                        .foregroundStyle(ROCKSColor.onDarkText)
                    Text("Service \u{2022} Mentorship \u{2022} Leadership")
                        .font(.caption2)
                        .tracking(0.6)
                        .foregroundStyle(ROCKSColor.goldLight)
                }
            }
            Spacer(minLength: 0)
            if let subtitle {
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ROCKSColor.onDarkText.opacity(0.75))
            }
        }
    }
}

// MARK: - Avatars

struct ROCKSAvatar: View {
    enum Size {
        case sm, md, lg

        var dimension: CGFloat {
            switch self {
            case .sm: 28
            case .md: 44
            case .lg: 76
            }
        }

        var initialsFont: Font {
            switch self {
            case .sm: .caption2.weight(.bold)
            case .md: .subheadline.weight(.bold)
            case .lg: .title3.weight(.bold)
            }
        }
    }

    let name: String
    var url: URL? = nil
    var size: Size = .md

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? (parts.last?.first.map(String.init) ?? "") : ""
        return (first + last).uppercased()
    }

    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        monogram
                    }
                }
            } else {
                monogram
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
        .overlay(Circle().stroke(ROCKSColor.goldStroke, lineWidth: 1))
        .accessibilityLabel("\(name) profile photo")
    }

    private var monogram: some View {
        Circle()
            .fill(ROCKSColor.charcoal)
            .overlay(
                Text(initials)
                    .font(size.initialsFont)
                    .foregroundStyle(ROCKSColor.goldLight)
            )
    }
}

/// Overlapping attendee/member avatars with an optional "+N" overflow bubble.
struct ROCKSAvatarStack: View {
    let members: [MemberProfile]
    var maxVisible: Int = 4

    private var visible: [MemberProfile] { Array(members.prefix(maxVisible)) }
    private var overflowCount: Int { max(0, members.count - maxVisible) }

    var body: some View {
        HStack(spacing: -10) {
            ForEach(visible) { member in
                ROCKSAvatar(name: member.fullName, url: member.avatarURL, size: .sm)
                    .overlay(Circle().stroke(ROCKSColor.cardBackground, lineWidth: 2))
            }
            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ROCKSColor.onDarkText)
                    .frame(width: 28, height: 28)
                    .background(ROCKSColor.surfaceDark, in: Circle())
                    .overlay(Circle().stroke(ROCKSColor.cardBackground, lineWidth: 2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(members.count) attending")
    }
}

// MARK: - Date Badge

struct ROCKSDateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(ROCKSColor.goldText)
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(ROCKSColor.primaryText)
        }
        .frame(width: 58, height: 64)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ROCKSColor.goldStroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
    }
}

// MARK: - Unread Badge

struct ROCKSBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 5 : 0)
                .frame(minWidth: 17, minHeight: 17)
                .background(ROCKSColor.badgeRed, in: Capsule())
                .accessibilityLabel("\(count) unread")
        }
    }
}

// MARK: - Segmented Tabs

struct ROCKSSegmentedTabs<Option: Hashable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(selection == option ? .semibold : .regular))
                        .foregroundStyle(selection == option ? ROCKSColor.black : ROCKSColor.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            selection == option ? ROCKSColor.gold : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(4)
        .background(ROCKSColor.insetBackground, in: Capsule())
    }
}

struct ROCKSPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Menu Row

struct ROCKSMenuRow: View {
    let title: String
    let systemImage: String
    var subtitle: String? = nil
    var goldAccent = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(goldAccent ? ROCKSColor.goldText : ROCKSColor.primaryText)
                .frame(width: 34, height: 34)
                .background(
                    (goldAccent ? ROCKSColor.gold.opacity(0.16) : ROCKSColor.insetBackground),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(goldAccent ? .semibold : .regular))
                    .foregroundStyle(goldAccent ? ROCKSColor.goldText : ROCKSColor.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(ROCKSColor.subtleText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ROCKSColor.subtleText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Quick Action Tile

struct ROCKSQuickActionTile: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ROCKSColor.goldText)
                .frame(width: 40, height: 40)
                .background(ROCKSColor.gold.opacity(0.14), in: Circle())
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ROCKSColor.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .padding(.vertical, 8)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
    }
}

// MARK: - Specialty Chip

struct ROCKSChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(ROCKSColor.goldText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ROCKSColor.gold.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(ROCKSColor.goldStroke, lineWidth: 1))
    }
}

// MARK: - Search Field

struct ROCKSSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ROCKSColor.subtleText)
            TextField(prompt, text: $text)
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.primaryText)
                .tint(ROCKSColor.goldText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ROCKSColor.subtleText)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(ROCKSColor.insetBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
