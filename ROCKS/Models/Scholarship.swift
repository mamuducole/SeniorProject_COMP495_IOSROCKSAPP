import Foundation

struct Scholarship: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let summary: String?
    let awardAmount: String?
    let deadline: Date
    let isActive: Bool
    let eligibility: String?
    let applicationURL: URL?

    init(
        id: UUID,
        title: String,
        summary: String? = nil,
        awardAmount: String? = nil,
        deadline: Date,
        isActive: Bool,
        eligibility: String? = nil,
        applicationURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.awardAmount = awardAmount
        self.deadline = deadline
        self.isActive = isActive
        self.eligibility = eligibility
        self.applicationURL = applicationURL
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: deadline)).day ?? 0
    }

    static let examples = [
        Scholarship(
            id: UUID(uuidString: "70000000-0000-0000-0000-000000000001") ?? UUID(),
            title: "ROCKS National Scholarship",
            summary: "Annual scholarship supporting members pursuing undergraduate and graduate degrees.",
            awardAmount: "$5,000",
            deadline: Calendar.current.date(byAdding: .day, value: 60, to: .now) ?? .now,
            isActive: true
        ),
        Scholarship(
            id: UUID(uuidString: "70000000-0000-0000-0000-000000000002") ?? UUID(),
            title: "Emerging Leaders Grant",
            summary: "Supports professional development and leadership coursework.",
            awardAmount: "$1,500",
            deadline: Calendar.current.date(byAdding: .day, value: 45, to: .now) ?? .now,
            isActive: true
        ),
        Scholarship(
            id: UUID(uuidString: "70000000-0000-0000-0000-000000000003") ?? UUID(),
            title: "Legacy of Leadership Award",
            summary: "Honors members demonstrating sustained mentorship and community service.",
            awardAmount: "$2,500",
            deadline: Calendar.current.date(byAdding: .day, value: 90, to: .now) ?? .now,
            isActive: true
        )
    ]
}
