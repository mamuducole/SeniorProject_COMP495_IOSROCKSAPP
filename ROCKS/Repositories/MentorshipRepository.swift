import Foundation

protocol MentorshipRepository: Sendable {
    func fetchMentors() async throws -> [MentorProfile]
    func fetchMentor(id: UUID) async throws -> MentorProfile?
    func fetchRequests() async throws -> [MentorshipRequest]
    func fetchConnections() async throws -> [MentorshipConnection]
    func sendRequest(mentorID: UUID, message: String) async throws -> MentorshipRequest
    func respondToRequest(id: UUID, accept: Bool) async throws
    func cancelRequest(id: UUID) async throws
    func endConnection(id: UUID) async throws
    func becomeMentor(settings: MentorDirectorySettings) async throws -> MentorProfile
    func hideMentorProfile() async throws
    func addGoal(connectionID: UUID, title: String, milestones: [String]) async throws -> MentorshipGoal
    func setGoalProgress(connectionID: UUID, goalID: UUID, percent: Int) async throws
    func setGoalComplete(connectionID: UUID, goalID: UUID, complete: Bool) async throws
    func addCheckIn(connectionID: UUID, note: String, meetingAt: Date, nextSteps: String?) async throws -> MentorshipCheckIn
}

actor MockMentorshipRepository: MentorshipRepository {
    private var mentors: [MentorProfile] = MentorProfile.examples
    private var requests: [MentorshipRequest] = MentorshipRequest.examples
    private var connections: [MentorshipConnection] = MentorshipConnection.examples

    func fetchMentors() async throws -> [MentorProfile] {
        mentors
    }

    func fetchMentor(id: UUID) async throws -> MentorProfile? {
        mentors.first { $0.id == id }
    }

    func fetchRequests() async throws -> [MentorshipRequest] {
        requests.sorted { $0.createdAt > $1.createdAt }
    }

    func fetchConnections() async throws -> [MentorshipConnection] {
        connections.sorted { $0.startedAt > $1.startedAt }
    }

    func sendRequest(mentorID: UUID, message: String) async throws -> MentorshipRequest {
        guard let mentor = mentors.first(where: { $0.id == mentorID && $0.isAcceptingMentees }) else {
            throw AppError.validation("That mentor is no longer available.")
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 1000 else {
            throw AppError.validation("Enter an introduction of up to 1,000 characters.")
        }
        if requests.contains(where: { $0.mentor.id == mentorID && $0.status == .pending }) {
            throw AppError.validation("You already have a pending request with this mentor.")
        }
        guard !connections.contains(where: { $0.mentor.id == mentorID && $0.mentee.id == MemberProfile.demo.id }) else {
            throw AppError.validation("You already have a mentorship with this mentor.")
        }
        let request = MentorshipRequest(
            id: UUID(),
            mentor: mentor,
            mentee: .demo,
            message: trimmed,
            status: .pending,
            createdAt: .now
        )
        requests.append(request)
        return request
    }

    func respondToRequest(id: UUID, accept: Bool) async throws {
        guard let index = requests.firstIndex(where: {
            $0.id == id && $0.mentor.id == MemberProfile.demo.id && $0.status == .pending
        }) else { throw AppError.unauthorized }
        requests[index].status = accept ? .accepted : .declined
        if accept {
            let request = requests[index]
            connections.insert(
                MentorshipConnection(
                    id: UUID(),
                    mentor: request.mentor,
                    mentee: request.mentee,
                    startedAt: .now,
                    goals: [],
                    checkIns: []
                ),
                at: 0
            )
        }
    }

    func cancelRequest(id: UUID) async throws {
        guard let index = requests.firstIndex(where: {
            $0.id == id && $0.mentee.id == MemberProfile.demo.id && $0.status == .pending
        }) else { throw AppError.unauthorized }
        requests.remove(at: index)
    }

    func endConnection(id: UUID) async throws {
        guard let index = connections.firstIndex(where: {
            $0.id == id && ($0.mentor.id == MemberProfile.demo.id || $0.mentee.id == MemberProfile.demo.id)
        }) else { throw AppError.unauthorized }
        connections.remove(at: index)
    }

    func hideMentorProfile() async throws {
        mentors.removeAll { $0.id == MemberProfile.demo.id }
    }

    func becomeMentor(settings: MentorDirectorySettings) async throws -> MentorProfile {
        let cleaned = settings.specialties.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else {
            throw AppError.validation("Add at least one mentorship specialty.")
        }
        var demoMember = MemberProfile.demo
        demoMember = MemberProfile(
            id: demoMember.id,
            firstName: demoMember.firstName,
            lastName: demoMember.lastName,
            email: demoMember.email,
            role: .mentor,
            rankTitle: demoMember.rankTitle,
            chapterName: demoMember.chapterName,
            bio: demoMember.bio,
            avatarURL: demoMember.avatarURL
        )
        let profile = MentorProfile(
            id: demoMember.id,
            member: demoMember,
            specialties: cleaned,
            mentoringBio: settings.bio.trimmingCharacters(in: .whitespacesAndNewlines),
            isAcceptingMentees: settings.isAccepting,
            careerField: settings.careerField,
            careerBackground: settings.careerBackground,
            interests: settings.interests,
            sharesChapter: settings.sharesChapter
        )
        mentors.removeAll { $0.id == profile.id }
        mentors.insert(profile, at: 0)
        return profile
    }

    func addGoal(connectionID: UUID, title: String, milestones: [String]) async throws -> MentorshipGoal {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.validation("Give the goal a title.")
        }
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else {
            throw AppError.validation("That mentorship connection is no longer available.")
        }
        let goal = MentorshipGoal(
            id: UUID(), title: trimmed, isComplete: false, dueDate: nil,
            milestones: milestones, history: [MentorshipGoalProgress(id: UUID(), percent: 0, recordedAt: .now)]
        )
        connections[index].goals.append(goal)
        return goal
    }

    func setGoalComplete(connectionID: UUID, goalID: UUID, complete: Bool) async throws {
        try await setGoalProgress(connectionID: connectionID, goalID: goalID, percent: complete ? 100 : 0)
    }

    func setGoalProgress(connectionID: UUID, goalID: UUID, percent: Int) async throws {
        guard (0...100).contains(percent) else { throw AppError.validation("Progress must be between 0 and 100.") }
        guard let connectionIndex = connections.firstIndex(where: { $0.id == connectionID }),
              let goalIndex = connections[connectionIndex].goals.firstIndex(where: { $0.id == goalID }) else {
            throw AppError.unauthorized
        }
        connections[connectionIndex].goals[goalIndex].isComplete = percent == 100
        connections[connectionIndex].goals[goalIndex].progressPercent = percent
        connections[connectionIndex].goals[goalIndex].history.append(
            MentorshipGoalProgress(id: UUID(), percent: percent, recordedAt: .now)
        )
    }

    func addCheckIn(connectionID: UUID, note: String, meetingAt: Date, nextSteps: String?) async throws -> MentorshipCheckIn {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.validation("Add a note for this check-in.")
        }
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else {
            throw AppError.validation("That mentorship connection is no longer available.")
        }
        let checkIn = MentorshipCheckIn(id: UUID(), note: trimmed, meetingAt: meetingAt, nextSteps: nextSteps)
        connections[index].checkIns.append(checkIn)
        connections[index].checkIns.sort { $0.meetingAt > $1.meetingAt }
        return checkIn
    }
}
