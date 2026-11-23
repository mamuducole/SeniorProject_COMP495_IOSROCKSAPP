import Foundation
import Supabase

// MARK: - Row DTOs

struct ProfileRow: Decodable, Sendable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String?
    let role: String?
    let rankTitle: String?
    let chapterID: UUID?
    let bio: String?
    let profileImagePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case role
        case rankTitle = "rank_title"
        case chapterID = "chapter_id"
        case bio
        case profileImagePath = "profile_image_path"
    }

    func toMember(chapterName: String?, assetURL: (String?) -> URL?) -> MemberProfile {
        MemberProfile(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            role: AppRole(rawValue: role ?? "member") ?? .member,
            rankTitle: rankTitle,
            chapterName: chapterName,
            bio: bio,
            avatarURL: assetURL(profileImagePath)
        )
    }
}

private struct EventRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let description: String?
    let category: String?
    let chapterID: UUID?
    let startsAt: Date
    let endsAt: Date?
    let venueName: String?
    let address: String?
    let registrationRequired: Bool
    let imagePath: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, address
        case chapterID = "chapter_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case venueName = "venue_name"
        case registrationRequired = "registration_required"
        case imagePath = "image_path"
    }
}

private struct RegistrationRow: Decodable, Sendable {
    let eventID: UUID
    let profileID: UUID

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case profileID = "profile_id"
    }
}

private struct PostRow: Decodable, Sendable {
    let id: UUID
    let authorID: UUID
    let kind: String
    let body: String
    let imagePath: String?
    let createdAt: Date
    let editedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, kind, body
        case authorID = "author_id"
        case imagePath = "image_path"
        case createdAt = "created_at"
        case editedAt = "edited_at"
    }
}

private struct IDRow: Decodable, Sendable {
    let id: UUID
}

private struct CommentRow: Decodable, Sendable {
    let id: UUID
    let postID: UUID
    let authorID: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body
        case postID = "post_id"
        case authorID = "author_id"
        case createdAt = "created_at"
    }
}

private struct LikeRow: Decodable, Sendable {
    let postID: UUID
    let profileID: UUID

    enum CodingKeys: String, CodingKey {
        case postID = "post_id"
        case profileID = "profile_id"
    }
}

private struct MentorRow: Decodable, Sendable {
    let profileID: UUID
    let specialties: [String]
    let mentoringBio: String?
    let isAccepting: Bool
    let careerField: String?
    let careerBackground: String?
    let interests: [String]
    let shareChapter: Bool

    enum CodingKeys: String, CodingKey {
        case specialties
        case profileID = "profile_id"
        case mentoringBio = "mentoring_bio"
        case isAccepting = "is_accepting"
        case careerField = "career_field"
        case careerBackground = "career_background"
        case shareChapter = "share_chapter"
        case interests
    }
}

private struct MentorDirectoryChapterRow: Decodable, Sendable {
    let id: UUID
    let chapterID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case chapterID = "chapter_id"
    }
}

private struct RequestRow: Decodable, Sendable {
    let id: UUID
    let menteeID: UUID
    let mentorID: UUID
    let message: String?
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, message, status
        case menteeID = "mentee_id"
        case mentorID = "mentor_id"
        case createdAt = "created_at"
    }
}

private struct ConnectionRow: Decodable, Sendable {
    let id: UUID
    let mentorID: UUID
    let menteeID: UUID
    let startedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case mentorID = "mentor_id"
        case menteeID = "mentee_id"
        case startedAt = "started_at"
    }
}

private struct GoalRow: Decodable, Sendable {
    let id: UUID
    let connectionID: UUID
    let title: String
    let isComplete: Bool
    let dueDate: String?
    let milestones: [String]
    let progressPercent: Int

    enum CodingKeys: String, CodingKey {
        case id, title
        case connectionID = "connection_id"
        case isComplete = "is_complete"
        case dueDate = "due_date"
        case milestones
        case progressPercent = "progress_percent"
    }

    var parsedDueDate: Date? {
        guard let dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dueDate)
    }
}

private struct GoalProgressRow: Decodable, Sendable {
    let id: UUID
    let goalID: UUID
    let progressPercent: Int
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case goalID = "goal_id"
        case progressPercent = "progress_percent"
        case recordedAt = "recorded_at"
    }
}

private struct CheckInRow: Decodable, Sendable {
    let id: UUID
    let connectionID: UUID
    let note: String
    let meetingAt: Date
    let nextSteps: String?

    enum CodingKeys: String, CodingKey {
        case id, note
        case connectionID = "connection_id"
        case meetingAt = "meeting_at"
        case nextSteps = "next_steps"
    }
}

private struct NotificationRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let body: String?
    let route: String?
    let isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, body, route
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

private struct ScholarshipRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let summary: String?
    let awardAmount: String?
    let deadline: Date
    let isActive: Bool
    let eligibility: String?
    let applicationURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, summary, deadline, eligibility
        case awardAmount = "award_amount"
        case isActive = "is_active"
        case applicationURL = "application_url"
    }
}

struct ChapterRow: Decodable, Sendable {
    let id: UUID
    let name: String
    let city: String?
    let state: String?
    let description: String?
    let latitude: Double?
    let longitude: Double?
    let isActive: Bool
    let installation: String?
    let mailingAddress: String?
    let contactPerson: String?
    let email: String?
    let website: String?
    let phone: String?

    enum CodingKeys: String, CodingKey {
        case id, name, city, state, description, latitude, longitude, installation, email, website, phone
        case isActive = "is_active"
        case mailingAddress = "mailing_address"
        case contactPerson = "contact_person"
    }

    func toChapter() -> Chapter {
        Chapter(
            id: id,
            name: name,
            city: city,
            state: state,
            description: description ?? "",
            latitude: latitude,
            longitude: longitude,
            isActive: isActive,
            mailingAddress: mailingAddress,
            contactPerson: contactPerson,
            email: email,
            website: website.flatMap { URL(string: $0) },
            installation: installation
        )
    }
}

/// Only `id, name` are selected for attribution lookups, so they cannot decode as `ChapterRow`.
struct ChapterNameRow: Decodable, Sendable {
    let id: UUID
    let name: String
}

// MARK: - Shared fetch helpers

/// Other members' attribution comes from `member_public_profiles`; migration 011
/// restricts biography and chapter and provides a separate mentor directory view.
enum MemberProfileSource {
    static let view = "member_public_profiles"
    static let columns = "id, first_name, last_name, role, rank_title, chapter_id, bio, profile_image_path"
}

private final class SupabaseFetchHelper: @unchecked Sendable {
    let client: SupabaseClient
    let assetURL: (String?) -> URL?

    init(client: SupabaseClient, assetURL: @escaping (String?) -> URL?) {
        self.client = client
        self.assetURL = assetURL
    }

    var currentUserID: UUID? { client.auth.currentUser?.id }

    func chapterNames() async throws -> [UUID: String] {
        let rows: [ChapterNameRow] = try await client
            .from("chapters")
            .select("id, name")
            .eq("is_active", value: true)
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.name) })
    }

    func profiles(ids: [UUID]) async throws -> [UUID: MemberProfile] {
        guard !ids.isEmpty else { return [:] }
        let chapters = try await chapterNames()
        let rows: [ProfileRow] = try await client
            .from(MemberProfileSource.view)
            .select(MemberProfileSource.columns)
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { row in
            let chapterName = row.chapterID.flatMap { chapters[$0] }
            return (row.id, row.toMember(chapterName: chapterName, assetURL: assetURL))
        })
    }
}

// MARK: - Chapters

struct SupabaseAdminRepository: AdminRepository {
    let client: SupabaseClient
    let configuration: AppConfiguration

    private struct Scope: Decodable {
        let role: AppRole
        let chapterID: UUID?
        enum CodingKeys: String, CodingKey {
            case role
            case chapterID = "chapter_id"
        }
    }

    private func scope() async throws -> Scope {
        guard let id = client.auth.currentUser?.id else { throw AppError.unauthenticated }
        let ready: Bool = try await client.rpc("admin_phase4_ready").execute().value
        guard ready else { throw AppError.unauthorized }
        let scope: Scope = try await client.from("profiles").select("role, chapter_id")
            .eq("id", value: id.uuidString).single().execute().value
        guard scope.role == .nationalAdmin || scope.role == .chapterAdmin else {
            throw AppError.unauthorized
        }
        return scope
    }

    func fetchManagedChapters() async throws -> [Chapter] {
        let scope = try await scope()
        let query = client.from("chapters").select().order("name")
        let rows: [ChapterRow]
        if scope.role == .chapterAdmin {
            guard let chapterID = scope.chapterID else { return [] }
            rows = try await client.from("chapters").select()
                .eq("id", value: chapterID.uuidString).execute().value
        } else {
            rows = try await query.execute().value
        }
        return rows.map { $0.toChapter() }
    }

    func updateChapter(id: UUID, description: String, email: String, website: String) async throws {
        _ = try await scope()
        let website = website.trimmingCharacters(in: .whitespacesAndNewlines)
        if !website.isEmpty {
            guard let components = URLComponents(string: website),
                  components.scheme?.lowercased() == "https", components.host != nil,
                  components.user == nil, components.password == nil else {
                throw AppError.validation("Enter an HTTPS website address without credentials.")
            }
        }
        struct Update: Encodable {
            let description: String
            let email: String
            let website: String
        }
        let rows: [ChapterRow] = try await client.from("chapters")
            .update(Update(description: description, email: email, website: website))
            .eq("id", value: id.uuidString).select().execute().value
        guard rows.count == 1 else { throw AppError.unauthorized }
    }

    func fetchActivity() async throws -> [AdministrativeActivity] {
        _ = try await scope()
        return try await client.from("administrative_activity").select()
            .order("occurred_at", ascending: false).order("id", ascending: false).limit(50)
            .execute().value
    }

    func fetchMembershipApplications(status: MembershipStatus) async throws -> [MembershipApplication] {
        _ = try await scope()
        struct Parameters: Encodable { let p_status: String }
        do {
            return try await client.rpc("admin_list_membership_applications", params: Parameters(p_status: status.rawValue))
                .execute().value
        } catch {
            throw SupabaseFeedRepository.mapError(error, fallback: "Unable to load membership applications.")
        }
    }

    func reviewMembership(profileID: UUID, decision: MembershipDecision) async throws {
        _ = try await scope()
        struct Parameters: Encodable {
            let p_profile_id: UUID
            let p_decision: String
        }
        do {
            try await client.rpc("admin_review_membership", params: Parameters(p_profile_id: profileID, p_decision: decision.rawValue))
                .execute()
        } catch let error as PostgrestError where error.code == "22023" {
            throw AppError.validation("This decision no longer applies. Refresh and try again.")
        } catch {
            throw SupabaseFeedRepository.mapError(error, fallback: "Unable to save the membership decision.")
        }
    }

    func fetchOpenReports() async throws -> [ContentReport] {
        let scope = try await scope()
        guard scope.role == .nationalAdmin else { return [] }
        do {
            return try await client.rpc("admin_list_open_reports").execute().value
        } catch {
            throw SupabaseFeedRepository.mapError(error, fallback: "Unable to load reported content.")
        }
    }

    func resolveReport(id: UUID, dismissed: Bool) async throws {
        _ = try await scope()
        struct Parameters: Encodable {
            let p_report_id: UUID
            let p_status: String
        }
        do {
            try await client.rpc("admin_resolve_report", params: Parameters(p_report_id: id, p_status: dismissed ? "dismissed" : "resolved"))
                .execute()
        } catch {
            throw SupabaseFeedRepository.mapError(error, fallback: "Unable to update this report.")
        }
    }

    /// Deletes the reported post or comment (national administrators only, enforced by RLS),
    /// which also removes its open reports.
    func removeReportedContent(_ report: ContentReport) async throws {
        let scope = try await scope()
        guard scope.role == .nationalAdmin else { throw AppError.unauthorized }
        let table: String
        let id: UUID
        if let postID = report.postID {
            (table, id) = ("posts", postID)
        } else if let commentID = report.commentID {
            (table, id) = ("post_comments", commentID)
        } else {
            throw AppError.invalidResponse
        }
        do {
            let rows: [IDRow] = try await client.from(table).delete()
                .eq("id", value: id.uuidString).select("id").execute().value
            guard !rows.isEmpty else { throw AppError.unauthorized }
        } catch {
            throw SupabaseFeedRepository.mapError(error, fallback: "Unable to remove this content.")
        }
    }
}

struct SupabaseChapterRepository: ChapterRepository {
    let client: SupabaseClient
    let configuration: AppConfiguration

    func fetchChapters() async throws -> [Chapter] {
        let rows: [ChapterRow] = try await client
            .from("chapters")
            .select()
            .eq("is_active", value: true)
            .order("name")
            .execute()
            .value
        return rows.map { $0.toChapter() }
    }

    func fetchChapter(id: UUID) async throws -> Chapter? {
        let rows: [ChapterRow] = try await client
            .from("chapters")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.toChapter()
    }
}

// MARK: - Events

struct SupabaseEventRepository: EventRepository {
    let client: SupabaseClient
    let configuration: AppConfiguration

    private var helper: SupabaseFetchHelper {
        SupabaseFetchHelper(client: client, assetURL: configuration.publicAssetURL(path:))
    }

    func fetchUpcomingEvents() async throws -> [ROCKSEvent] {
        try await fetchEvents(where: { query in
            query
                .gte("starts_at", value: ISO8601DateFormatter().string(from: .now))
                .order("starts_at", ascending: true)
        })
    }

    func fetchMyEvents() async throws -> [ROCKSEvent] {
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        let registrations: [RegistrationRow] = try await client
            .from("event_registrations")
            .select()
            .eq("profile_id", value: uid.uuidString)
            .execute()
            .value
        let ids = registrations.map(\.eventID)
        guard !ids.isEmpty else { return [] }
        return try await fetchEvents(where: { query in
            query
                .in("id", values: ids.map(\.uuidString))
                .gte("starts_at", value: ISO8601DateFormatter().string(from: .now))
                .order("starts_at", ascending: true)
        }, registeredIDs: Set(ids))
    }

    func fetchPastEvents() async throws -> [ROCKSEvent] {
        try await fetchEvents(where: { query in
            query
                .lt("starts_at", value: ISO8601DateFormatter().string(from: .now))
                .order("starts_at", ascending: false)
        })
    }

    func fetchEvent(id: UUID) async throws -> ROCKSEvent? {
        try await fetchEvents(where: { query in
            query.eq("id", value: id.uuidString).limit(1)
        }).first
    }

    private func fetchEvents(
        where apply: (PostgrestFilterBuilder) -> PostgrestTransformBuilder,
        registeredIDs: Set<UUID>? = nil
    ) async throws -> [ROCKSEvent] {
        let rows: [EventRow] = try await apply(
            client
                .from("events")
                .select()
                .eq("is_published", value: true)
        )
        .execute()
        .value

        guard !rows.isEmpty else { return [] }

        let eventIDs = rows.map(\.id)
        let chapters = try await helper.chapterNames()

        let registrations: [RegistrationRow] = try await client
            .from("event_registrations")
            .select()
            .in("event_id", values: eventIDs.map(\.uuidString))
            .execute()
            .value

        let myRegistrations: Set<UUID>
        if let registeredIDs {
            myRegistrations = registeredIDs
        } else if let uid = helper.currentUserID {
            myRegistrations = Set(registrations.filter { $0.profileID == uid }.map(\.eventID))
        } else {
            myRegistrations = []
        }

        return rows.map { row in
            ROCKSEvent(
                id: row.id,
                title: row.title,
                chapterName: row.chapterID.flatMap { chapters[$0] },
                startsAt: row.startsAt,
                endsAt: row.endsAt,
                venueName: row.venueName,
                locationLabel: row.address ?? row.venueName,
                eventDescription: row.description,
                category: row.category,
                imageURL: configuration.publicAssetURL(path: row.imagePath),
                imageName: nil,
                registrationRequired: row.registrationRequired,
                isRegisteredByCurrentUser: myRegistrations.contains(row.id)
            )
        }
    }
}

// MARK: - Members

struct SupabaseMemberRepository: MemberRepository {
    let client: SupabaseClient
    let configuration: AppConfiguration

    private var helper: SupabaseFetchHelper {
        SupabaseFetchHelper(client: client, assetURL: configuration.publicAssetURL(path:))
    }

    func fetchMembers() async throws -> [MemberProfile] {
        let chapters = try await helper.chapterNames()
        let rows: [ProfileRow] = try await client
            .from(MemberProfileSource.view)
            .select(MemberProfileSource.columns)
            .order("last_name")
            .execute()
            .value
        return rows.map { row in
            row.toMember(chapterName: row.chapterID.flatMap { chapters[$0] }, assetURL: configuration.publicAssetURL(path:))
        }
    }

    func fetchProfile(id: UUID) async throws -> MemberProfile? {
        let chapters = try await helper.chapterNames()
        let rows: [ProfileRow] = try await client
            .from(MemberProfileSource.view)
            .select(MemberProfileSource.columns)
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first.map {
            $0.toMember(chapterName: $0.chapterID.flatMap { chapters[$0] }, assetURL: configuration.publicAssetURL(path:))
        }
    }

    func updateOwnProfile(_ update: ProfileUpdate) async throws -> MemberProfile {
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        let valid = try update.validated()
        struct Update: Encodable {
            let firstName: String
            let lastName: String
            let rankTitle: String?
            let bio: String?

            enum CodingKeys: String, CodingKey {
                case firstName = "first_name"
                case lastName = "last_name"
                case rankTitle = "rank_title"
                case bio
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(firstName, forKey: .firstName)
                try container.encode(lastName, forKey: .lastName)
                try container.encode(rankTitle, forKey: .rankTitle)
                try container.encode(bio, forKey: .bio)
            }
        }
        do {
            let rows: [IDRow] = try await client.from("profiles")
                .update(Update(
                    firstName: valid.firstName, lastName: valid.lastName,
                    rankTitle: valid.rankTitle.isEmpty ? nil : valid.rankTitle,
                    bio: valid.bio.isEmpty ? nil : valid.bio
                ))
                .eq("id", value: uid.uuidString)
                .select("id")
                .execute()
                .value
            guard !rows.isEmpty else { throw AppError.unauthorized }
        } catch {
            throw SupabaseFeedRepository.mapError(error, fallback: "Unable to save your profile.")
        }
        guard let profile = try await fetchProfile(id: uid) else { throw AppError.invalidResponse }
        return profile
    }
}

// MARK: - Community Feed

struct SupabaseFeedRepository: FeedRepository {
    let client: SupabaseClient
    let configuration: AppConfiguration

    private var helper: SupabaseFetchHelper {
        SupabaseFetchHelper(client: client, assetURL: configuration.publicAssetURL(path:))
    }

    func fetchPosts() async throws -> [Post] {
        do {
            let postRows: [PostRow] = try await client
                .from("posts")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            return try await compose(postRows)
        } catch {
            throw Self.mapError(error, fallback: "Unable to load the community feed right now.")
        }
    }

    func fetchPost(id: UUID) async throws -> Post? {
        do {
            let postRows: [PostRow] = try await client
                .from("posts")
                .select()
                .eq("id", value: id.uuidString)
                .limit(1)
                .execute()
                .value
            return try await compose(postRows).first
        } catch {
            throw Self.mapError(error, fallback: "Unable to load this post right now.")
        }
    }

    func createPost(body: String, imageName: String?) async throws -> Post {
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        let trimmed = try FeedValidation.postBody(body)
        struct PostInsert: Encodable {
            let authorID: UUID
            let kind: String
            let body: String

            enum CodingKeys: String, CodingKey {
                case authorID = "author_id"
                case kind, body
            }
        }
        do {
            let row: PostRow = try await client
                .from("posts")
                .insert(PostInsert(authorID: uid, kind: PostKind.member.rawValue, body: trimmed))
                .select()
                .single()
                .execute()
                .value
            let author = try await helper.profiles(ids: [uid])[uid] ?? MemberProfile.placeholder(name: "ROCKS Member")
            return Post(id: row.id, author: author, body: row.body, createdAt: row.createdAt, editedAt: row.editedAt)
        } catch {
            throw Self.mapError(error, fallback: "Unable to publish your post.")
        }
    }

    func updatePost(id: UUID, body: String) async throws -> Post {
        guard helper.currentUserID != nil else { throw AppError.unauthenticated }
        let trimmed = try FeedValidation.postBody(body)
        struct BodyUpdate: Encodable {
            let body: String
        }
        do {
            // RLS silently filters rows the member may not edit, so an empty result means "not allowed".
            let rows: [IDRow] = try await client
                .from("posts")
                .update(BodyUpdate(body: trimmed))
                .eq("id", value: id.uuidString)
                .select("id")
                .execute()
                .value
            guard !rows.isEmpty else { throw AppError.unauthorized }
        } catch {
            throw Self.mapError(error, fallback: "Unable to save your changes.")
        }
        guard let post = try await fetchPost(id: id) else { throw AppError.invalidResponse }
        return post
    }

    func deletePost(id: UUID) async throws {
        guard helper.currentUserID != nil else { throw AppError.unauthenticated }
        do {
            let rows: [IDRow] = try await client
                .from("posts")
                .delete()
                .eq("id", value: id.uuidString)
                .select("id")
                .execute()
                .value
            guard !rows.isEmpty else { throw AppError.unauthorized }
        } catch {
            throw Self.mapError(error, fallback: "Unable to delete this post.")
        }
    }

    func setLiked(postID: UUID, liked: Bool) async throws {
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        struct LikeInsert: Encodable {
            let postID: UUID
            let profileID: UUID

            enum CodingKeys: String, CodingKey {
                case postID = "post_id"
                case profileID = "profile_id"
            }
        }
        do {
            if liked {
                // ON CONFLICT DO NOTHING: the composite primary key prevents duplicate likes,
                // and ignoring duplicates avoids needing an UPDATE policy on post_likes.
                try await client
                    .from("post_likes")
                    .upsert(
                        LikeInsert(postID: postID, profileID: uid),
                        onConflict: "post_id,profile_id",
                        returning: .minimal,
                        ignoreDuplicates: true
                    )
                    .execute()
            } else {
                try await client
                    .from("post_likes")
                    .delete(returning: .minimal)
                    .eq("post_id", value: postID.uuidString)
                    .eq("profile_id", value: uid.uuidString)
                    .execute()
            }
        } catch {
            throw Self.mapError(error, fallback: "Unable to update your like.")
        }
    }

    func addComment(postID: UUID, body: String) async throws -> PostComment {
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        let trimmed = try FeedValidation.commentBody(body)
        struct CommentInsert: Encodable {
            let postID: UUID
            let authorID: UUID
            let body: String

            enum CodingKeys: String, CodingKey {
                case postID = "post_id"
                case authorID = "author_id"
                case body
            }
        }
        do {
            let row: CommentRow = try await client
                .from("post_comments")
                .insert(CommentInsert(postID: postID, authorID: uid, body: trimmed))
                .select()
                .single()
                .execute()
                .value
            let author = try await helper.profiles(ids: [uid])[uid] ?? MemberProfile.placeholder(name: "ROCKS Member")
            return PostComment(id: row.id, author: author, body: row.body, createdAt: row.createdAt)
        } catch {
            throw Self.mapError(error, fallback: "Unable to add your comment.")
        }
    }

    func deleteComment(id: UUID, postID: UUID) async throws {
        guard helper.currentUserID != nil else { throw AppError.unauthenticated }
        do {
            let rows: [IDRow] = try await client
                .from("post_comments")
                .delete()
                .eq("id", value: id.uuidString)
                .eq("post_id", value: postID.uuidString)
                .select("id")
                .execute()
                .value
            guard !rows.isEmpty else { throw AppError.unauthorized }
        } catch {
            throw Self.mapError(error, fallback: "Unable to delete this comment.")
        }
    }

    func report(_ target: ReportTarget, reason: ReportReason) async throws {
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        struct ReportInsert: Encodable {
            let reporterID: UUID
            let postID: UUID?
            let commentID: UUID?
            let reason: String

            enum CodingKeys: String, CodingKey {
                case reporterID = "reporter_id"
                case postID = "post_id"
                case commentID = "comment_id"
                case reason
            }
        }
        let insert: ReportInsert
        switch target {
        case .post(let id): insert = ReportInsert(reporterID: uid, postID: id, commentID: nil, reason: reason.rawValue)
        case .comment(let id): insert = ReportInsert(reporterID: uid, postID: nil, commentID: id, reason: reason.rawValue)
        }
        do {
            try await client.from("content_reports").insert(insert, returning: .minimal).execute()
        } catch let error as PostgrestError where error.code == "23505" {
            throw AppError.validation("You already reported this. An administrator will review it.")
        } catch {
            throw Self.mapError(error, fallback: "Unable to send your report.")
        }
    }

    private func compose(_ postRows: [PostRow]) async throws -> [Post] {
        guard !postRows.isEmpty else { return [] }

        let postIDs = postRows.map(\.id)

        let commentRows: [CommentRow] = try await client
            .from("post_comments")
            .select()
            .in("post_id", values: postIDs.map(\.uuidString))
            .order("created_at", ascending: true)
            .execute()
            .value

        let likeRows: [LikeRow] = try await client
            .from("post_likes")
            .select()
            .in("post_id", values: postIDs.map(\.uuidString))
            .execute()
            .value

        let profileIDs = Set(postRows.map(\.authorID) + commentRows.map(\.authorID))
        let profiles = try await helper.profiles(ids: Array(profileIDs))
        let uid = helper.currentUserID

        var likeCounts: [UUID: Int] = [:]
        var likedByMe: Set<UUID> = []
        for like in likeRows {
            likeCounts[like.postID, default: 0] += 1
            if like.profileID == uid { likedByMe.insert(like.postID) }
        }

        var commentsByPost: [UUID: [PostComment]] = [:]
        for comment in commentRows {
            let author = profiles[comment.authorID] ?? Self.unknownAuthor(id: comment.authorID)
            commentsByPost[comment.postID, default: []].append(
                PostComment(id: comment.id, author: author, body: comment.body, createdAt: comment.createdAt)
            )
        }

        return postRows.map { row in
            Post(
                id: row.id,
                author: profiles[row.authorID] ?? Self.unknownAuthor(id: row.authorID),
                kind: PostKind(rawValue: row.kind) ?? .member,
                body: row.body,
                imageName: nil,
                imageURL: configuration.publicAssetURL(path: row.imagePath),
                createdAt: row.createdAt,
                editedAt: row.editedAt,
                likeCount: likeCounts[row.id] ?? 0,
                isLikedByCurrentUser: likedByMe.contains(row.id),
                comments: commentsByPost[row.id] ?? []
            )
        }
    }

    /// Keeps the real author ID so ownership checks still work if a profile is not readable.
    private static func unknownAuthor(id: UUID) -> MemberProfile {
        MemberProfile(id: id, firstName: "ROCKS", lastName: "Member")
    }

    static func mapError(_ error: Error, fallback: String) -> AppError {
        if let appError = error as? AppError { return appError }
        if let postgrest = error as? PostgrestError {
            switch postgrest.code {
            case "42501", "PGRST301", "PGRST302":
                return .unauthorized
            case "23503":
                return .validation("This content is no longer available, or your member profile has not been set up yet.")
            case "23514":
                return .validation("That text is too long or empty. Please revise it and try again.")
            default:
                return .database(fallback)
            }
        }
        if error is URLError { return .network(error) }
        return .database(fallback)
    }
}

// MARK: - Mentorship

struct SupabaseMentorshipRepository: MentorshipRepository {
    let client: SupabaseClient
    let configuration: AppConfiguration

    private var helper: SupabaseFetchHelper {
        SupabaseFetchHelper(client: client, assetURL: configuration.publicAssetURL(path:))
    }

    /// The server enforces participant and approved-member rules; this only confirms a signed-in session.
    private func requireSecureBackend() async throws {
        guard client.auth.currentUser != nil else { throw AppError.unauthenticated }
        let ready: Bool = try await client.rpc("mentorship_phase3_ready").execute().value
        guard ready else { throw AppError.unauthenticated }
    }

    private func mentorChapterNames(for rows: [MentorRow]) async throws -> [UUID: String] {
        let ids = rows.filter(\.shareChapter).map(\.profileID)
        guard !ids.isEmpty else { return [:] }
        let shared: [MentorDirectoryChapterRow] = try await client
            .from("mentor_directory_chapters")
            .select("id, chapter_id")
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        let chapters = try await helper.chapterNames()
        var names: [UUID: String] = [:]
        for row in shared {
            if let chapterID = row.chapterID, let name = chapters[chapterID] {
                names[row.id] = name
            }
        }
        return names
    }

    private func makeMentor(_ row: MentorRow, member: MemberProfile, chapterName: String?) -> MentorProfile {
        let sharedMember = MemberProfile(
            id: member.id, firstName: member.firstName, lastName: member.lastName,
            role: member.role, rankTitle: member.rankTitle,
            chapterName: row.shareChapter ? chapterName : nil,
            avatarURL: member.avatarURL
        )
        return MentorProfile(
            id: row.profileID, member: sharedMember, specialties: row.specialties,
            mentoringBio: row.mentoringBio, isAcceptingMentees: row.isAccepting,
            careerField: row.careerField, careerBackground: row.careerBackground,
            interests: row.interests, sharesChapter: row.shareChapter
        )
    }

    func fetchMentors() async throws -> [MentorProfile] {
        try await requireSecureBackend()
        let rows: [MentorRow] = try await client
            .from("mentorship_profiles")
            .select()
            .eq("directory_visible", value: true)
            .execute()
            .value
        guard !rows.isEmpty else { return [] }
        let profiles = try await helper.profiles(ids: rows.map(\.profileID))
        let chapterNames = try await mentorChapterNames(for: rows)
        return rows.compactMap { row in
            guard let member = profiles[row.profileID] else { return nil }
            return makeMentor(row, member: member, chapterName: chapterNames[row.profileID])
        }
    }

    func fetchMentor(id: UUID) async throws -> MentorProfile? {
        try await fetchMentors().first { $0.id == id }
    }

    func fetchRequests() async throws -> [MentorshipRequest] {
        try await requireSecureBackend()
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        let rows: [RequestRow] = try await client
            .from("mentorship_requests")
            .select()
            .or("mentee_id.eq.\(uid.uuidString),mentor_id.eq.\(uid.uuidString)")
            .order("created_at", ascending: false)
            .execute()
            .value
        return try await composeRequests(rows)
    }

    func fetchConnections() async throws -> [MentorshipConnection] {
        try await requireSecureBackend()
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        let rows: [ConnectionRow] = try await client
            .from("mentorship_connections")
            .select()
            .or("mentee_id.eq.\(uid.uuidString),mentor_id.eq.\(uid.uuidString)")
            .eq("status", value: "active")
            .order("started_at", ascending: false)
            .execute()
            .value
        guard !rows.isEmpty else { return [] }

        let connectionIDs = rows.map(\.id)
        async let goalRows: [GoalRow] = client
            .from("mentorship_goals")
            .select()
            .in("connection_id", values: connectionIDs.map(\.uuidString))
            .execute()
            .value
        async let checkInRows: [CheckInRow] = client
            .from("mentorship_check_ins")
            .select()
            .in("connection_id", values: connectionIDs.map(\.uuidString))
            .order("meeting_at", ascending: false)
            .execute()
            .value

        let mentors = try await mentorMap(ids: rows.map(\.mentorID))
        let mentees = try await helper.profiles(ids: rows.map(\.menteeID))
        let goals = try await goalRows
        let checkIns = try await checkInRows
        let progress = try await progressHistory(goalIDs: goals.map(\.id))

        var goalsByConnection: [UUID: [MentorshipGoal]] = [:]
        for goal in goals {
            goalsByConnection[goal.connectionID, default: []].append(
                MentorshipGoal(
                    id: goal.id, title: goal.title, isComplete: goal.isComplete, dueDate: goal.parsedDueDate,
                    milestones: goal.milestones, progressPercent: goal.progressPercent,
                    history: progress[goal.id] ?? []
                )
            )
        }
        var checkInsByConnection: [UUID: [MentorshipCheckIn]] = [:]
        for checkIn in checkIns {
            checkInsByConnection[checkIn.connectionID, default: []].append(
                MentorshipCheckIn(id: checkIn.id, note: checkIn.note, meetingAt: checkIn.meetingAt, nextSteps: checkIn.nextSteps)
            )
        }

        return rows.compactMap { row in
            guard let mentor = mentors[row.mentorID], let mentee = mentees[row.menteeID] else { return nil }
            return MentorshipConnection(
                id: row.id,
                mentor: mentor,
                mentee: mentee,
                startedAt: row.startedAt,
                goals: goalsByConnection[row.id] ?? [],
                checkIns: checkInsByConnection[row.id] ?? []
            )
        }
    }

    func sendRequest(mentorID: UUID, message: String) async throws -> MentorshipRequest {
        try await requireSecureBackend()
        struct Parameters: Encodable {
            let p_mentor_id: UUID
            let p_message: String
        }
        let id: UUID = try await client.rpc(
            "mentorship_send_request",
            params: Parameters(p_mentor_id: mentorID, p_message: message)
        ).execute().value
        let row: RequestRow = try await client
            .from("mentorship_requests")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        guard let request = try await composeRequests([row]).first else {
            throw AppError.invalidResponse
        }
        return request
    }

    func respondToRequest(id: UUID, accept: Bool) async throws {
        try await requireSecureBackend()
        struct Parameters: Encodable {
            let p_request_id: UUID
            let p_accept: Bool
        }
        try await client.rpc("mentorship_respond_request", params: Parameters(p_request_id: id, p_accept: accept)).execute()
    }

    func cancelRequest(id: UUID) async throws {
        try await requireSecureBackend()
        struct Parameters: Encodable {
            let p_request_id: UUID
        }
        try await client.rpc("mentorship_cancel_request", params: Parameters(p_request_id: id)).execute()
    }

    func endConnection(id: UUID) async throws {
        try await requireSecureBackend()
        struct Parameters: Encodable {
            let p_connection_id: UUID
        }
        try await client.rpc("mentorship_end_connection", params: Parameters(p_connection_id: id)).execute()
    }

    func hideMentorProfile() async throws {
        try await requireSecureBackend()
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        struct Update: Encodable { let directory_visible = false }
        let rows: [MentorRow] = try await client.from("mentorship_profiles")
            .update(Update()).eq("profile_id", value: uid.uuidString).select().execute().value
        guard !rows.isEmpty else { throw AppError.unauthorized }
    }

    func becomeMentor(settings: MentorDirectorySettings) async throws -> MentorProfile {
        try await requireSecureBackend()
        guard let uid = helper.currentUserID else { throw AppError.unauthenticated }
        let cleaned = settings.specialties.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else {
            throw AppError.validation("Add at least one mentorship specialty.")
        }
        struct MentorUpsert: Encodable {
            let profileID: UUID
            let specialties: [String]
            let mentoringBio: String
            let isAccepting: Bool
            let directoryVisible: Bool
            let shareChapter: Bool
            let careerField: String
            let careerBackground: String
            let interests: [String]

            enum CodingKeys: String, CodingKey {
                case specialties
                case profileID = "profile_id"
                case mentoringBio = "mentoring_bio"
                case isAccepting = "is_accepting"
                case directoryVisible = "directory_visible"
                case shareChapter = "share_chapter"
                case careerField = "career_field"
                case careerBackground = "career_background"
                case interests
            }
        }
        try await client
            .from("mentorship_profiles")
            .upsert(MentorUpsert(
                profileID: uid, specialties: cleaned, mentoringBio: settings.bio, isAccepting: settings.isAccepting,
                directoryVisible: true, shareChapter: settings.sharesChapter,
                careerField: settings.careerField, careerBackground: settings.careerBackground,
                interests: settings.interests
            ))
            .execute()

        guard let mentor = try await fetchMentors().first(where: { $0.id == uid }) else {
            throw AppError.invalidResponse
        }
        return mentor
    }

    func addGoal(connectionID: UUID, title: String, milestones: [String]) async throws -> MentorshipGoal {
        try await requireSecureBackend()
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.validation("Give the goal a title.")
        }
        struct GoalInsert: Encodable {
            let connectionID: UUID
            let title: String
            let milestones: [String]

            enum CodingKeys: String, CodingKey {
                case connectionID = "connection_id"
                case title, milestones
            }
        }
        let row: GoalRow = try await client
            .from("mentorship_goals")
            .insert(GoalInsert(connectionID: connectionID, title: trimmed, milestones: milestones))
            .select()
            .single()
            .execute()
            .value
        let history = try await progressHistory(goalIDs: [row.id])
        return MentorshipGoal(
            id: row.id, title: row.title, isComplete: row.isComplete, dueDate: row.parsedDueDate,
            milestones: row.milestones, progressPercent: row.progressPercent, history: history[row.id] ?? []
        )
    }

    func setGoalComplete(connectionID: UUID, goalID: UUID, complete: Bool) async throws {
        try await setGoalProgress(connectionID: connectionID, goalID: goalID, percent: complete ? 100 : 0)
    }

    func setGoalProgress(connectionID: UUID, goalID: UUID, percent: Int) async throws {
        try await requireSecureBackend()
        guard (0...100).contains(percent) else { throw AppError.validation("Progress must be between 0 and 100.") }
        struct ProgressUpdate: Encodable {
            let progressPercent: Int

            enum CodingKeys: String, CodingKey {
                case progressPercent = "progress_percent"
            }
        }
        let rows: [GoalRow] = try await client
            .from("mentorship_goals")
            .update(ProgressUpdate(progressPercent: percent))
            .eq("id", value: goalID.uuidString)
            .eq("connection_id", value: connectionID.uuidString)
            .select()
            .execute().value
        guard !rows.isEmpty else { throw AppError.unauthorized }
    }

    func addCheckIn(connectionID: UUID, note: String, meetingAt: Date, nextSteps: String?) async throws -> MentorshipCheckIn {
        try await requireSecureBackend()
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.validation("Add a note for this check-in.")
        }
        struct CheckInInsert: Encodable {
            let connectionID: UUID
            let note: String
            let meetingAt: Date
            let nextSteps: String?

            enum CodingKeys: String, CodingKey {
                case connectionID = "connection_id"
                case note
                case meetingAt = "meeting_at"
                case nextSteps = "next_steps"
            }
        }
        let row: CheckInRow = try await client
            .from("mentorship_check_ins")
            .insert(CheckInInsert(connectionID: connectionID, note: trimmed, meetingAt: meetingAt, nextSteps: nextSteps))
            .select()
            .single()
            .execute()
            .value
        return MentorshipCheckIn(id: row.id, note: row.note, meetingAt: row.meetingAt, nextSteps: row.nextSteps)
    }

    private func progressHistory(goalIDs: [UUID]) async throws -> [UUID: [MentorshipGoalProgress]] {
        guard !goalIDs.isEmpty else { return [:] }
        let rows: [GoalProgressRow] = try await client.from("mentorship_goal_progress")
            .select().in("goal_id", values: goalIDs.map(\.uuidString))
            .order("recorded_at", ascending: true).execute().value
        var result: [UUID: [MentorshipGoalProgress]] = [:]
        for row in rows {
            result[row.goalID, default: []].append(
                MentorshipGoalProgress(id: row.id, percent: row.progressPercent, recordedAt: row.recordedAt)
            )
        }
        return result
    }

    private func mentorMap(ids: [UUID]) async throws -> [UUID: MentorProfile] {
        guard !ids.isEmpty else { return [:] }
        let rows: [MentorRow] = try await client
            .from("mentorship_profiles")
            .select()
            .in("profile_id", values: ids.map(\.uuidString))
            .execute()
            .value
        let profiles = try await helper.profiles(ids: ids)
        let chapterNames = try await mentorChapterNames(for: rows)
        var map: [UUID: MentorProfile] = [:]
        for row in rows {
            guard let member = profiles[row.profileID] else { continue }
            map[row.profileID] = makeMentor(row, member: member, chapterName: chapterNames[row.profileID])
        }
        return map
    }

    private func composeRequests(_ rows: [RequestRow]) async throws -> [MentorshipRequest] {
        guard !rows.isEmpty else { return [] }
        let mentors = try await mentorMap(ids: rows.map(\.mentorID))
        let mentees = try await helper.profiles(ids: rows.map(\.menteeID))
        return rows.compactMap { row in
            guard let mentor = mentors[row.mentorID], let mentee = mentees[row.menteeID] else { return nil }
            return MentorshipRequest(
                id: row.id,
                mentor: mentor,
                mentee: mentee,
                message: row.message ?? "",
                status: MentorshipRequestStatus(rawValue: row.status) ?? .pending,
                createdAt: row.createdAt
            )
        }
    }
}

// MARK: - Notifications

struct SupabaseNotificationRepository: NotificationRepository {
    let client: SupabaseClient
    let configuration: AppConfiguration

    func fetchNotifications() async throws -> [AppNotification] {
        guard let uid = client.auth.currentUser?.id else { throw AppError.unauthenticated }
        let rows: [NotificationRow] = try await client
            .from("notifications")
            .select()
            .eq("profile_id", value: uid.uuidString)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
        return rows.map {
            AppNotification(
                id: $0.id,
                title: $0.title,
                body: $0.body,
                routePath: $0.route,
                isRead: $0.isRead,
                createdAt: $0.createdAt
            )
        }
    }

    func markAllRead() async throws {
        guard let uid = client.auth.currentUser?.id else { throw AppError.unauthenticated }
        do {
            try await client
                .from("notifications")
                .update(ReadUpdate(isRead: true))
                .eq("profile_id", value: uid.uuidString)
                .eq("is_read", value: false)
                .execute()
        } catch {
            throw SupabaseFeedRepository.mapError(error, fallback: "Unable to update notifications.")
        }
    }

    func markRead(id: UUID) async throws {
        guard client.auth.currentUser != nil else { throw AppError.unauthenticated }
        do {
            let rows: [IDRow] = try await client
                .from("notifications")
                .update(ReadUpdate(isRead: true))
                .eq("id", value: id.uuidString)
                .select("id")
                .execute()
                .value
            guard !rows.isEmpty else { throw AppError.unauthorized }
        } catch {
            throw SupabaseFeedRepository.mapError(error, fallback: "Unable to update this notification.")
        }
    }

    private struct ReadUpdate: Encodable {
        let isRead: Bool

        enum CodingKeys: String, CodingKey {
            case isRead = "is_read"
        }
    }
}

// MARK: - Scholarships

struct SupabaseScholarshipRepository: ScholarshipRepository {
    let client: SupabaseClient
    let configuration: AppConfiguration

    func fetchActiveScholarships() async throws -> [Scholarship] {
        let rows: [ScholarshipRow] = try await client
            .from("scholarships")
            .select()
            .eq("is_active", value: true)
            .order("deadline", ascending: true)
            .execute()
            .value
        return rows.map {
            Scholarship(
                id: $0.id,
                title: $0.title,
                summary: $0.summary,
                awardAmount: $0.awardAmount,
                deadline: $0.deadline,
                isActive: $0.isActive,
                eligibility: $0.eligibility,
                applicationURL: $0.applicationURL.flatMap { URL(string: $0) }
            )
        }
    }
}

// MARK: - News

private struct NewsArticleRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let summary: String
    let body: String
    let category: String
    let publishedAt: Date
    let isFeatured: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, summary, body, category
        case publishedAt = "published_at"
        case isFeatured = "is_featured"
    }

    var article: NewsArticle {
        NewsArticle(
            id: id,
            headline: title,
            summary: summary,
            body: body,
            publishedAt: publishedAt,
            category: category,
            isFeatured: isFeatured
        )
    }
}

struct SupabaseNewsRepository: NewsRepository {
    let client: SupabaseClient

    func fetchLatestNews() async throws -> [NewsArticle] {
        let rows: [NewsArticleRow] = try await client
            .from("news_articles")
            .select()
            .eq("is_published", value: true)
            .order("published_at", ascending: false)
            .limit(50)
            .execute()
            .value
        return rows.map(\.article)
    }

    func fetchArticle(id: UUID) async throws -> NewsArticle? {
        let rows: [NewsArticleRow] = try await client
            .from("news_articles")
            .select()
            .eq("id", value: id.uuidString)
            .eq("is_published", value: true)
            .limit(1)
            .execute()
            .value
        return rows.first?.article
    }
}
