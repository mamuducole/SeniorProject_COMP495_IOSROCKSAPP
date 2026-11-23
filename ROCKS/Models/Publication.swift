import Foundation
import Observation
import PDFKit

struct Publication: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let issue: String?
    let publishedAt: Date?
    let description: String
    let series: String?
    let bundledPDF: String?
    let remoteURL: URL?

    var isRefresh: Bool {
        series?.localizedCaseInsensitiveCompare("ROCKS REFRESH") == .orderedSame
    }

    var publicationYear: Int? {
        guard let publishedAt else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.component(.year, from: publishedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, issue, description, series
        case publishedAt = "published_at"
        case bundledPDF = "bundled_pdf"
        case remoteURL = "remote_url"
    }
}

enum PublicationError: LocalizedError {
    case missingCatalog
    case invalidCatalog
    case missingPDF
    case invalidURL
    case downloadFailed
    case invalidPDF

    var errorDescription: String? {
        switch self {
        case .missingCatalog: "The publications catalog is unavailable."
        case .invalidCatalog: "The publications catalog contains invalid information."
        case .missingPDF: "The publication file is not available on this device."
        case .invalidURL: "The publication address is not a permitted HTTPS URL."
        case .downloadFailed: "The publication could not be downloaded. Check your connection and try again."
        case .invalidPDF: "The publication is not a readable PDF."
        }
    }
}

struct PublicationRepository {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func fetchPublications() throws -> [Publication] {
        guard let url = bundle.url(forResource: "publications", withExtension: "json") else {
            throw PublicationError.missingCatalog
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let publications = try decoder.decode([Publication].self, from: Data(contentsOf: url))
        guard Set(publications.map(\.id)).count == publications.count,
              publications.allSatisfy({ publication in
                  !publication.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && (publication.bundledPDF != nil || publication.remoteURL != nil)
              }) else {
            throw PublicationError.invalidCatalog
        }
        return publications.sorted {
            switch ($0.publishedAt, $1.publishedAt) {
            case let (left?, right?) where left != right: return left > right
            case (_?, nil): return true
            case (nil, _?): return false
            default: return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
    }

    func bundledURL(for publication: Publication) -> URL? {
        guard let name = publication.bundledPDF,
              !name.isEmpty,
              name == (name as NSString).lastPathComponent,
              name.lowercased().hasSuffix(".pdf") else { return nil }
        return bundle.url(forResource: String(name.dropLast(4)), withExtension: "pdf")
    }

    func document(for publication: Publication) async throws -> PDFDocument {
        if let url = bundledURL(for: publication) {
            guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else {
                throw PublicationError.invalidPDF
            }
            return document
        }
        guard let url = publication.remoteURL else { throw PublicationError.missingPDF }
        guard Self.isPublicHTTPS(url) else { throw PublicationError.invalidURL }
        let data: Data
        let response: URLResponse
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration, delegate: PublicationRedirectGuard(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            if error is CancellationError { throw error }
            throw PublicationError.downloadFailed
        }
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let finalURL = http.url, Self.isPublicHTTPS(finalURL) else {
            throw PublicationError.downloadFailed
        }
        guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else {
            throw PublicationError.invalidPDF
        }
        return document
    }

    fileprivate static func isPublicHTTPS(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        return components.scheme?.lowercased() == "https"
            && components.host != nil
            && components.user == nil
            && components.password == nil
            && components.query == nil
            && components.fragment == nil
    }
}

private final class PublicationRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url, PublicationRepository.isPublicHTTPS(url) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}

@MainActor
@Observable
final class PublicationLibrary {
    private let defaults: UserDefaults
    private let savedKey = "publications.saved"
    private let pagesKey = "publications.pages"
    private(set) var savedIDs: Set<UUID>
    private(set) var pages: [String: Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        savedIDs = Set((defaults.stringArray(forKey: savedKey) ?? []).compactMap(UUID.init(uuidString:)))
        pages = defaults.dictionary(forKey: pagesKey) as? [String: Int] ?? [:]
    }

    func isSaved(_ publication: Publication) -> Bool {
        savedIDs.contains(publication.id)
    }

    func toggleSaved(_ publication: Publication) {
        if !savedIDs.insert(publication.id).inserted {
            savedIDs.remove(publication.id)
        }
        defaults.set(savedIDs.map(\.uuidString), forKey: savedKey)
    }

    func page(for publication: Publication) -> Int {
        max(0, pages[publication.id.uuidString] ?? 0)
    }

    func setPage(_ page: Int, for publication: Publication) {
        pages[publication.id.uuidString] = max(0, page)
        defaults.set(pages, forKey: pagesKey)
    }

    static func filtered(_ publications: [Publication], search: String, issue: String?, year: Int?) -> [Publication] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return publications.filter { publication in
            (query.isEmpty || publication.title.localizedCaseInsensitiveContains(query))
                && (issue == nil || publication.issue == issue)
                && (year == nil || publication.publicationYear == year)
        }
    }
}
