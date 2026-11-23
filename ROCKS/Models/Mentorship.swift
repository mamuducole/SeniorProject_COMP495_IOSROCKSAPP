import Foundation

struct MentorProfile: Identifiable, Codable, Hashable, Sendable {
    /// Same as the underlying profile id.
    let id: UUID
    let member: MemberProfile
    let specialties: [String]
    let mentoringBio: String?
    let isAcceptingMentees: Bool
    var careerField: String? = nil
    var careerBackground: String? = nil
    var interests: [String] = []
    var sharesChapter: Bool = false

    static let examples = [
        MentorProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001") ?? UUID(),
            member: MemberProfile.examples[0],
            specialties: ["Leadership", "Career Transition", "Officer Development"],
            mentoringBio: "I help junior officers turn assignments into leadership opportunities. Expect candid feedback and a plan.",
            isAcceptingMentees: true
        ),
        MentorProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000003") ?? UUID(),
            member: MemberProfile.examples[2],
            specialties: ["Professional Development", "Warrant Officer Path"],
            mentoringBio: "Former CW5 focused on technical-track careers and professional education.",
            isAcceptingMentees: true
        ),
        MentorProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000004") ?? UUID(),
            member: MemberProfile.examples[3],
            specialties: ["Scholarships", "Community Service", "Chapter Leadership"],
            mentoringBio: "Chapter president mentoring members on balancing service, career, and family.",
            isAcceptingMentees: false
        ),
        MentorProfile(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000002") ?? UUID(),
            member: MemberProfile.examples[1],
            specialties: ["Logistics", "Graduate School"],
            mentoringBio: "Logistics officer who navigated grad school while serving — happy to help you do the same.",
            isAcceptingMentees: true
        )
    ]
}

struct MentorDirectorySettings: Sendable {
    let specialties: [String]
    let bio: String
    let careerField: String
    let careerBackground: String
    let interests: [String]
    let sharesChapter: Bool
    let isAccepting: Bool
}

enum MentorshipRequestStatus: String, Codable, Sendable {
    case pending
    case accepted
    case declined

    var displayName: String { rawValue.capitalized }
}

struct MentorshipRequest: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let mentor: MentorProfile
    let mentee: MemberProfile
    let message: String
    var status: MentorshipRequestStatus
    let createdAt: Date

    static let examples = [
        MentorshipRequest(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000001") ?? UUID(),
            mentor: MentorProfile.examples[1],
            mentee: .demo,
            message: "Looking for guidance on professional military education next year.",
            status: .pending,
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now
        )
    ]
}

struct MentorshipConnection: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let mentor: MentorProfile
    let mentee: MemberProfile
    let startedAt: Date
    var goals: [MentorshipGoal]
    var checkIns: [MentorshipCheckIn]

    var completedGoalCount: Int { goals.filter(\.isComplete).count }

    var progress: Double {
        guard !goals.isEmpty else { return 0 }
        return Double(goals.reduce(0) { $0 + ($1.isComplete ? 100 : $1.progressPercent) }) / Double(goals.count * 100)
    }

    static let examples = [
        MentorshipConnection(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000001") ?? UUID(),
            mentor: MentorProfile.examples[0],
            mentee: .demo,
            startedAt: Calendar.current.date(byAdding: .month, value: -4, to: .now) ?? .now,
            goals: [
                MentorshipGoal(
                    id: UUID(uuidString: "51000000-0000-0000-0000-000000000001") ?? UUID(),
                    title: "Complete company command reading list",
                    isComplete: true,
                    dueDate: nil,
                    progressPercent: 100
                ),
                MentorshipGoal(
                    id: UUID(uuidString: "51000000-0000-0000-0000-000000000002") ?? UUID(),
                    title: "Draft five-year career plan",
                    isComplete: true,
                    dueDate: nil,
                    progressPercent: 100
                ),
                MentorshipGoal(
                    id: UUID(uuidString: "51000000-0000-0000-0000-000000000003") ?? UUID(),
                    title: "Apply for the ROCKS National Scholarship",
                    isComplete: false,
                    dueDate: Calendar.current.date(byAdding: .day, value: 30, to: .now)
                )
            ],
            checkIns: [
                MentorshipCheckIn(
                    id: UUID(uuidString: "52000000-0000-0000-0000-000000000001") ?? UUID(),
                    note: "Kickoff call — aligned on goals and meeting cadence.",
                    meetingAt: Calendar.current.date(byAdding: .month, value: -4, to: .now) ?? .now
                ),
                MentorshipCheckIn(
                    id: UUID(uuidString: "52000000-0000-0000-0000-000000000002") ?? UUID(),
                    note: "Reviewed career plan draft; next step is scholarship application.",
                    meetingAt: Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
                )
            ]
        )
    ]
}

struct MentorshipGoal: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    var isComplete: Bool
    let dueDate: Date?
    var milestones: [String] = []
    var progressPercent: Int = 0
    var history: [MentorshipGoalProgress] = []
}

struct MentorshipGoalProgress: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let percent: Int
    let recordedAt: Date
}

struct MentorshipCheckIn: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let note: String
    let meetingAt: Date
    var nextSteps: String? = nil
}
