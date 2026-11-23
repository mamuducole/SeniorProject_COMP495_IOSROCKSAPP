import SwiftUI

/// Active scholarships with deadline countdowns.
struct ScholarshipsView: View {
    @Environment(AppState.self) private var appState
    @State private var scholarships: [Scholarship] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ROCKSTheme.spacingMD) {
                ZStack(alignment: .bottomLeading) {
                    Image("rocksScholarship")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                    LinearGradient.rocksPhotoScrim
                        .frame(height: 180)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scholarships")
                            .font(ROCKSFont.title)
                            .foregroundStyle(.white)
                        Text("Investing in the leaders of tomorrow.")
                            .font(.subheadline)
                            .foregroundStyle(ROCKSColor.onDarkText.opacity(0.9))
                    }
                    .padding(20)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if scholarships.isEmpty && !isLoading {
                    EmptyStateView(title: "No active scholarships", systemImage: "graduationcap", message: "New scholarship opportunities will be announced here.")
                        .frame(minHeight: 220)
                } else {
                    ForEach(scholarships) { scholarship in
                        NavigationLink(destination: ScholarshipDetailView(scholarship: scholarship)) {
                            ScholarshipCardView(scholarship: scholarship)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Scholarships")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            scholarships = try await appState.environment.scholarshipRepository.fetchActiveScholarships()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load scholarships right now."
        }
    }
}

struct ScholarshipCardView: View {
    let scholarship: Scholarship

    var body: some View {
        ROCKSCard {
            HStack(spacing: 14) {
                Image(systemName: "graduationcap.fill")
                    .font(.title3)
                    .foregroundStyle(ROCKSColor.black)
                    .frame(width: 46, height: 46)
                    .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(scholarship.title)
                        .font(.headline)
                        .foregroundStyle(ROCKSColor.primaryText)
                    if let amount = scholarship.awardAmount {
                        Text(amount)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ROCKSColor.goldText)
                    }
                    Text("Deadline \(scholarship.deadline.formatted(date: .abbreviated, time: .omitted)) \u{2022} \(scholarship.daysRemaining)d left")
                        .font(.caption)
                        .foregroundStyle(ROCKSColor.subtleText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ROCKSColor.subtleText)
            }
        }
    }
}

struct ScholarshipDetailView: View {
    let scholarship: Scholarship

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ROCKSTheme.spacingMD) {
                HStack(spacing: 16) {
                    Image(systemName: "graduationcap.fill")
                        .font(.title)
                        .foregroundStyle(ROCKSColor.black)
                        .frame(width: 64, height: 64)
                        .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scholarship.title)
                            .font(ROCKSFont.titleSmall)
                            .foregroundStyle(ROCKSColor.primaryText)
                        if let amount = scholarship.awardAmount {
                            Text(amount)
                                .font(.headline)
                                .foregroundStyle(ROCKSColor.goldText)
                        }
                    }
                }

                ROCKSCard {
                    VStack(alignment: .leading, spacing: 10) {
                        detailRow(icon: "calendar", title: "Application deadline", value: scholarship.deadline.formatted(date: .complete, time: .omitted))
                        detailRow(icon: "clock.fill", title: "Time remaining", value: "\(scholarship.daysRemaining) days")
                        if let summary = scholarship.summary {
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(ROCKSColor.subtleText)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                    }
                }

                if let eligibility = scholarship.eligibility {
                    ROCKSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Eligibility")
                                .font(.headline)
                                .foregroundStyle(ROCKSColor.primaryText)
                            Text(eligibility)
                                .font(.body)
                                .foregroundStyle(ROCKSColor.subtleText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let applicationURL = scholarship.applicationURL {
                    Link(destination: applicationURL) {
                        Label("Apply / Learn More", systemImage: "arrow.up.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ROCKSColor.gold)
                    .foregroundStyle(ROCKSColor.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text("Scholarship details are provided by The ROCKS, Inc. For questions or to apply when no link is listed, contact your chapter president.")
                    .font(.footnote)
                    .foregroundStyle(ROCKSColor.subtleText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Scholarship")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(ROCKSColor.goldText)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.subtleText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ROCKSColor.primaryText)
        }
    }
}
