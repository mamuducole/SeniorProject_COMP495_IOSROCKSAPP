import Foundation
import Observation

@MainActor
@Observable
final class MentorshipViewModel {
    private(set) var mentors: [MentorProfile] = []
    private(set) var requests: [MentorshipRequest] = []
    private(set) var connections: [MentorshipConnection] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    var errorMessage: String?

    private let environment: AppEnvironment
    let currentUserID: UUID?

    init(environment: AppEnvironment, currentUserID: UUID? = nil) {
        self.environment = environment
        self.currentUserID = currentUserID
    }

    var pendingRequests: [MentorshipRequest] {
        requests.filter { $0.status == .pending }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let mentorList = environment.mentorshipRepository.fetchMentors()
        async let requestList = environment.mentorshipRepository.fetchRequests()
        async let connectionList = environment.mentorshipRepository.fetchConnections()

        do {
            mentors = try await mentorList
            requests = try await requestList
            connections = try await connectionList
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load mentorship right now."
        }
    }

    func sendRequest(to mentor: MentorProfile, message: String) async -> Bool {
        guard !isSending else { return false }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let request = try await environment.mentorshipRepository.sendRequest(mentorID: mentor.id, message: message)
            requests.insert(request, at: 0)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to send your mentorship request."
            return false
        }
    }

    func respond(to request: MentorshipRequest, accept: Bool) async {
        do {
            try await environment.mentorshipRepository.respondToRequest(id: request.id, accept: accept)
            if let index = requests.firstIndex(where: { $0.id == request.id }) {
                requests[index].status = accept ? .accepted : .declined
            }
            connections = try await environment.mentorshipRepository.fetchConnections()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update that request."
        }
    }

    func cancel(_ request: MentorshipRequest) async {
        do {
            try await environment.mentorshipRepository.cancelRequest(id: request.id)
            requests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to cancel that request."
        }
    }

    func end(_ connection: MentorshipConnection) async -> Bool {
        do {
            try await environment.mentorshipRepository.endConnection(id: connection.id)
            connections.removeAll { $0.id == connection.id }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to end this mentorship."
            return false
        }
    }

    func hideMentorProfile() async -> Bool {
        do {
            try await environment.mentorshipRepository.hideMentorProfile()
            mentors.removeAll { $0.id == currentUserID }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to hide your mentor profile."
            return false
        }
    }

    func becomeMentor(settings: MentorDirectorySettings) async -> Bool {
        do {
            let profile = try await environment.mentorshipRepository.becomeMentor(settings: settings)
            mentors.removeAll { $0.id == profile.id }
            mentors.insert(profile, at: 0)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to create your mentor profile."
            return false
        }
    }

    static func matchReasons(for mentor: MentorProfile, preferences: String) -> [String] {
        guard mentor.isAcceptingMentees else { return [] }
        let terms = preferences.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let fields = mentor.specialties + mentor.interests + [mentor.careerField].compactMap { $0 }
        return terms.filter { term in
            fields.contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }

    static func matches(
        _ mentor: MentorProfile,
        search: String,
        availableOnly: Bool,
        career: String,
        background: String,
        chapter: String
    ) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchable = [mentor.member.fullName, mentor.member.chapterName, mentor.careerField, mentor.careerBackground]
            .compactMap { $0 } + mentor.specialties + mentor.interests
        return (query.isEmpty || searchable.contains { $0.localizedCaseInsensitiveContains(query) })
            && (!availableOnly || mentor.isAcceptingMentees)
            && (career.isEmpty || mentor.careerField == career)
            && (background.isEmpty || mentor.careerBackground == background)
            && (chapter.isEmpty || mentor.member.chapterName == chapter)
    }

    func addGoal(_ title: String, milestones: [String] = [], to connection: MentorshipConnection) async -> Bool {
        do {
            let goal = try await environment.mentorshipRepository.addGoal(
                connectionID: connection.id, title: title, milestones: milestones
            )
            if let index = connections.firstIndex(where: { $0.id == connection.id }) {
                connections[index].goals.append(goal)
            }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to add that goal."
            return false
        }
    }

    func toggleGoal(_ goal: MentorshipGoal, in connection: MentorshipConnection) async {
        await updateProgress(goal, percent: goal.isComplete ? 0 : 100, in: connection)
    }

    func updateProgress(_ goal: MentorshipGoal, percent: Int, in connection: MentorshipConnection) async {
        do {
            try await environment.mentorshipRepository.setGoalProgress(
                connectionID: connection.id, goalID: goal.id, percent: percent
            )
            connections = try await environment.mentorshipRepository.fetchConnections()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to update that goal."
        }
    }

    func addCheckIn(note: String, meetingAt: Date, nextSteps: String? = nil, to connection: MentorshipConnection) async -> Bool {
        do {
            let checkIn = try await environment.mentorshipRepository.addCheckIn(
                connectionID: connection.id, note: note, meetingAt: meetingAt, nextSteps: nextSteps
            )
            if let index = connections.firstIndex(where: { $0.id == connection.id }) {
                connections[index].checkIns.append(checkIn)
                connections[index].checkIns.sort { $0.meetingAt > $1.meetingAt }
            }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to log that check-in."
            return false
        }
    }
}
