import Foundation

protocol NewsRepository: Sendable {
    func fetchLatestNews() async throws -> [NewsArticle]
    func fetchArticle(id: UUID) async throws -> NewsArticle?
}

struct MockNewsRepository: NewsRepository {
    func fetchArticle(id: UUID) async throws -> NewsArticle? {
        NewsArticle.examples.first { $0.id == id }
    }

    func fetchLatestNews() async throws -> [NewsArticle] {
        NewsArticle.examples.sorted { $0.publishedAt > $1.publishedAt }
    }
}
