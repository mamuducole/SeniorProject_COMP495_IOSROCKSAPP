import SwiftUI

struct Program: Identifiable, Hashable {
    let title: String
    let summary: String
    let systemImage: String

    var id: String { title }

    static let examples = [
        Program(title: "Mentorship", summary: "Guidance and professional development through mentor relationships.", systemImage: "person.2.fill"),
        Program(title: "Leadership Development", summary: "Learn from experienced leaders and strengthen professional leadership.", systemImage: "chart.line.uptrend.xyaxis"),
        Program(title: "Scholarships", summary: "Scholarship support for students and future military leaders.", systemImage: "graduationcap.fill"),
        Program(title: "Networking", summary: "Build professional relationships across the ROCKS community.", systemImage: "network"),
        Program(title: "Leadership Outreach", summary: "Connect students and future officers with experienced military professionals.", systemImage: "trophy.fill"),
        Program(title: "Community Service", summary: "Apply leadership through community involvement and outreach.", systemImage: "hands.sparkles.fill")
    ]
}

struct ProgramInformation: Identifiable, Hashable {
    let title: String
    let systemImage: String
    let introduction: String
    let overview: String
    let purpose: String
    let focusAreas: [String]
    let benefits: String
    let missionConnection: String
    let officialURL: URL

    var id: String { title }

    static let details: [ProgramInformation] = [
        ProgramInformation(
            title: "Leadership Development",
            systemImage: "chart.line.uptrend.xyaxis",
            introduction: "Supporting professional growth across military, ROTC, and civilian leadership.",
            overview: "Leadership Development is central to The ROCKS, Inc. The organization supports the professional growth of military officers, ROTC cadets, and civilian leaders through mentorship, leadership education, and opportunities to learn from experienced professionals.",
            purpose: "Help members develop the knowledge, confidence, leadership abilities, and professional relationships needed for continued growth throughout their careers.",
            focusAreas: [
                "Professional leadership education and development",
                "Mentorship from experienced military and civilian leaders",
                "Career planning and advancement",
                "Leadership discussions, presentations, and conferences",
                "Communication and decision-making skills",
                "Understanding important Army and Department of Defense issues"
            ],
            benefits: "Members have opportunities to gain professional guidance, learn from experienced leaders, strengthen leadership capabilities, and connect with people who can support career development.",
            missionConnection: "Leadership and professional development are foundational to the ROCKS mission of strengthening military officers and civilian leaders.",
            officialURL: OfficialLinks.programs
        ),
        ProgramInformation(
            title: "Networking",
            systemImage: "network",
            introduction: "Building meaningful professional relationships throughout the ROCKS community.",
            overview: "Networking is a core competency of The ROCKS, Inc. The organization provides opportunities for military officers, cadets, retired service members, and civilian professionals to build professional relationships.",
            purpose: "Promote professional connections, information sharing, mentorship, and collaboration among members at different stages of their careers.",
            focusAreas: [
                "Connecting junior and senior military leaders",
                "Developing professional relationships",
                "Encouraging mentorship and peer support",
                "Sharing professional experiences and resources",
                "Supporting connections through local chapters",
                "Building lasting relationships across the ROCKS community"
            ],
            benefits: "Members can expand professional relationships, exchange career knowledge, receive guidance, and become part of a supportive leadership community.",
            missionConnection: "Networking supports the ROCKS vision of serving as a premier mentoring and networking organization for the United States Armed Forces.",
            officialURL: OfficialLinks.generalInformation
        ),
        ProgramInformation(
            title: "Leadership Outreach",
            systemImage: "trophy.fill",
            introduction: "Connecting college students and future military leaders with experienced professionals.",
            overview: "The ROCKS Leadership Outreach program supports college students and future military leaders by connecting them with experienced military professionals. Outreach teams visit selected colleges and universities to provide professional development guidance and help students prepare for the transition from college to military service.",
            purpose: "Prepare ROTC cadets and future officers for the professional expectations, responsibilities, and challenges associated with military leadership.",
            focusAreas: [
                "ROTC cadet development",
                "College and university outreach",
                "Preparing students for military service",
                "Understanding military evaluation systems",
                "Financial management education",
                "Professional conduct and career development",
                "Mentorship from experienced officers"
            ],
            benefits: "Students can gain guidance from experienced military leaders, strengthen their understanding of military careers, and receive information to help them transition into professional service.",
            missionConnection: "Leadership Outreach advances the ROCKS commitment to developing future officers and supporting educational institutions, including Historically Black Colleges and Universities.",
            officialURL: OfficialLinks.programs
        ),
        ProgramInformation(
            title: "Community Service",
            systemImage: "hands.sparkles.fill",
            introduction: "Extending leadership, service, and engagement into the communities ROCKS members serve.",
            overview: "Community involvement and outreach are important components of The ROCKS, Inc. mission. Through local chapters and member involvement, ROCKS encourages service and activities that strengthen communities and support others.",
            purpose: "Encourage members to use their leadership experience, knowledge, and commitment to service to make meaningful contributions to their communities.",
            focusAreas: [
                "Community involvement and outreach",
                "Supporting educational and mentorship initiatives",
                "Encouraging volunteer participation",
                "Supporting underserved communities",
                "Connecting leadership development with service",
                "Building relationships between members and their communities"
            ],
            benefits: "Community involvement gives members opportunities to contribute time and expertise, strengthen community connections, and demonstrate leadership through service.",
            missionConnection: "Community Involvement/Outreach is an official ROCKS core competency that reinforces the organization's commitment to service and leadership.",
            officialURL: OfficialLinks.generalInformation
        )
    ]

    static func detail(for title: String) -> ProgramInformation? {
        details.first { $0.title == title }
    }
}

struct ProgramsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LEARN AND LEAD")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(ROCKSColor.goldText)
                        Text("Keep growing.")
                            .font(ROCKSFont.display)
                        Text("Publications, scholarships, and opportunities to develop as a leader.")
                            .font(.subheadline)
                            .foregroundStyle(ROCKSColor.subtleText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    NavigationLink(destination: NewsView()) {
                        ROCKSCard {
                            ROCKSMenuRow(title: "ROCKS News & Publications", systemImage: "book.closed", subtitle: "Explore ROCKS REFRESH and saved publications", goldAccent: true)
                        }
                    }
                    .buttonStyle(ROCKSPressStyle())

                    NavigationLink(destination: ScholarshipsView()) {
                        ROCKSCard {
                            ROCKSMenuRow(title: "Scholarship Center", systemImage: "graduationcap", subtitle: "Explore scholarship information and opportunities")
                        }
                    }
                    .buttonStyle(ROCKSPressStyle())

                    ZStack(alignment: .bottomLeading) {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .background {
                                Image("rocksHeroLeadership")
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipped()
                        LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Programs")
                                .font(.system(size: 40, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                            Text("Our programs support mentorship, professional growth, scholarship, networking, and outreach.")
                                .font(.body)
                                .foregroundStyle(ROCKSColor.onDarkText.opacity(0.9))
                                .frame(maxWidth: 360, alignment: .leading)
                        }
                        .padding(20)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                    VStack(spacing: 12) {
                        ForEach(Program.examples) { program in
                            NavigationLink(destination: programDestination(for: program)) {
                                HStack(alignment: .center, spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(ROCKSColor.gold.opacity(0.16))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: program.systemImage)
                                            .font(.title3)
                                            .foregroundStyle(ROCKSColor.goldText)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(program.title)
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(ROCKSColor.primaryText)
                                        Text(program.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(ROCKSColor.subtleText)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(ROCKSColor.goldText)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, minHeight: 104)
                                .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ROCKSColor.divider, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(ROCKSColor.background)
            .navigationTitle("Learn")
            .navigationBarTitleDisplayMode(.inline)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func programDestination(for program: Program) -> some View {
        switch program.title {
        case "Mentorship":
            CHAMPMentorshipView()
        case "Scholarships":
            ScholarshipInfoView()
        default:
            if let information = ProgramInformation.detail(for: program.title) {
                ProgramDetailView(information: information)
            } else {
                ContentUnavailableView(program.title, systemImage: program.systemImage, description: Text(program.summary))
            }
        }
    }
}

private struct ProgramDetailView: View {
    let information: ProgramInformation
    @State private var presentedLink: IdentifiableURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                identityCard
                informationCard(title: "About This Program", text: information.overview)
                informationCard(title: "Program Purpose", text: information.purpose)
                focusCard
                informationCard(title: "Member Benefits", text: information.benefits)
                informationCard(title: "Connection to the ROCKS Mission", text: information.missionConnection)
                Button {
                    presentedLink = IdentifiableURL(url: information.officialURL)
                } label: {
                    Label("Learn More on Website", systemImage: "arrow.up.right.square")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(ROCKSColor.black)
                        .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityHint("Opens official ROCKS program information")
                .padding(.top, 2)
            }
            .padding(20)
        }
        .background(ROCKSColor.background)
        .navigationTitle(information.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(ROCKSColor.goldText)
        .officialLinkSheet($presentedLink)
    }

    private var identityCard: some View {
        ROCKSCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: information.systemImage)
                    .font(.title)
                    .foregroundStyle(ROCKSColor.black)
                    .frame(width: 56, height: 56)
                    .background(ROCKSColor.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(information.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(ROCKSColor.primaryText)
                    Text(information.introduction)
                        .font(.subheadline)
                        .foregroundStyle(ROCKSColor.subtleText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func informationCard(title: String, text: String) -> some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var focusCard: some View {
        ROCKSCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Key Focus Areas")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ROCKSColor.primaryText)
                ForEach(information.focusAreas, id: \.self) { focus in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ROCKSColor.goldText)
                            .padding(.top, 3)
                        Text(focus)
                            .font(.subheadline)
                            .foregroundStyle(ROCKSColor.subtleText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

#Preview {
    ProgramsView()
}
