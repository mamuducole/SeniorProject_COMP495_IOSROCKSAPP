import Foundation

protocol ScholarshipRepository: Sendable {
    func fetchActiveScholarships() async throws -> [Scholarship]
}

extension ScholarshipRepository {
    /// Count of active scholarships ordered by nearest deadline — drives the dashboard stat.
    func upcomingDeadlineCount() async throws -> Int {
        try await fetchActiveScholarships().filter { $0.deadline > .now }.count
    }
}

struct MockScholarshipRepository: ScholarshipRepository {
    func fetchActiveScholarships() async throws -> [Scholarship] {
        Scholarship.examples.sorted { $0.deadline < $1.deadline }
    }
}
