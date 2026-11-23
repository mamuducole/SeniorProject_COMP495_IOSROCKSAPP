import Foundation
import Observation

@MainActor
@Observable
final class MembersViewModel {
    var searchText = ""

    private(set) var members: [MemberProfile] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var filteredMembers: [MemberProfile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return members }
        return members.filter { member in
            member.fullName.localizedCaseInsensitiveContains(query)
                || (member.rankTitle?.localizedCaseInsensitiveContains(query) ?? false)
                || (member.chapterName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            members = try await environment.memberRepository.fetchMembers()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load the member directory right now."
        }
    }
}
