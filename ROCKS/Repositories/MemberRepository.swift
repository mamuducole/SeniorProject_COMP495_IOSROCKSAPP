import Foundation

protocol MemberRepository: Sendable {
    func fetchMembers() async throws -> [MemberProfile]
    func fetchProfile(id: UUID) async throws -> MemberProfile?
    func updateOwnProfile(_ update: ProfileUpdate) async throws -> MemberProfile
}

/// Fields members may change themselves. Role, chapter, email, and membership are server-owned.
struct ProfileUpdate: Equatable, Sendable {
    let firstName: String
    let lastName: String
    let rankTitle: String
    let bio: String

    func validated() throws -> ProfileUpdate {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rank = rankTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let about = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty, !last.isEmpty else { throw AppError.validation("Enter your first and last name.") }
        guard first.count <= 80, last.count <= 80 else { throw AppError.validation("Names can be up to 80 characters.") }
        guard rank.count <= 80 else { throw AppError.validation("Rank or title can be up to 80 characters.") }
        guard about.count <= 1000 else { throw AppError.validation("Your biography can be up to 1,000 characters.") }
        return ProfileUpdate(firstName: first, lastName: last, rankTitle: rank, bio: about)
    }
}

struct MockMemberRepository: MemberRepository {
    func fetchMembers() async throws -> [MemberProfile] {
        MemberProfile.examples
    }

    func fetchProfile(id: UUID) async throws -> MemberProfile? {
        if id == MemberProfile.demo.id { return .demo }
        return MemberProfile.examples.first { $0.id == id } ?? .demo
    }

    /// Demo changes are not persisted.
    func updateOwnProfile(_ update: ProfileUpdate) async throws -> MemberProfile {
        let valid = try update.validated()
        let demo = MemberProfile.demo
        return MemberProfile(
            id: demo.id, firstName: valid.firstName, lastName: valid.lastName, email: demo.email,
            role: demo.role, rankTitle: valid.rankTitle.isEmpty ? nil : valid.rankTitle,
            chapterName: demo.chapterName, bio: valid.bio.isEmpty ? nil : valid.bio, avatarURL: demo.avatarURL
        )
    }
}
