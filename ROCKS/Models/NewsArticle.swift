import Foundation

struct NewsArticle: Identifiable, Codable, Hashable {
    let id: UUID
    let headline: String
    let summary: String
    let body: String
    let publishedAt: Date
    let category: String
    let isFeatured: Bool

    static let examples = [
        NewsArticle(id: UUID(), headline: "Building the Next Generation of Leaders", summary: "Mentorship remains at the heart of the ROCKS community.", body: "The ROCKS, Inc. brings leaders together to shape talent through mentorship, professional development, and service.", publishedAt: .now, category: "Community", isFeatured: true),
        NewsArticle(id: UUID(), headline: "Connect With Your Local Chapter", summary: "Find opportunities to learn, serve, and grow together.", body: "Explore chapter events and connect with members in your area.", publishedAt: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now, category: "Chapters", isFeatured: false)
    ]
}
