import XCTest
import UIKit
@testable import ROCKS

@MainActor
final class PublicationTests: XCTestCase {
    private func publication(
        title: String = "Mentorship",
        issue: String? = "Week 12",
        date: Date? = nil,
        bundledPDF: String? = "issue.pdf",
        remoteURL: URL? = nil
    ) -> Publication {
        Publication(id: UUID(), title: title, issue: issue, publishedAt: date,
                    description: "Test fixture", series: "ROCKS REFRESH",
                    bundledPDF: bundledPDF, remoteURL: remoteURL)
    }

    private func fixtureBundle(pdfData: Data? = nil, catalog: String = "[]") throws -> Bundle {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let plist: [String: String] = ["CFBundleIdentifier": "test.publications.\(UUID().uuidString)",
                                       "CFBundleName": "PublicationFixture"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url.appendingPathComponent("Info.plist"))
        try Data(catalog.utf8).write(to: url.appendingPathComponent("publications.json"))
        try pdfData?.write(to: url.appendingPathComponent("issue.pdf"))
        return try XCTUnwrap(Bundle(url: url))
    }

    func testLoadsCatalogAndRejectsDuplicateIdentifiers() throws {
        let id = UUID()
        let item = """
        {"id":"\(id.uuidString)","title":"Issue","description":"Example","bundled_pdf":"issue.pdf"}
        """
        let repository = PublicationRepository(bundle: try fixtureBundle(catalog: "[\(item)]"))
        XCTAssertEqual(try repository.fetchPublications().first?.id, id)
        let duplicate = PublicationRepository(bundle: try fixtureBundle(catalog: "[\(item),\(item)]"))
        XCTAssertThrowsError(try duplicate.fetchPublications())
    }

    func testBundledPDFOpensOfflineAndMissingOrInvalidPDFErrors() async throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        let data = renderer.pdfData { context in
            context.beginPage()
            context.beginPage()
        }
        let repository = PublicationRepository(bundle: try fixtureBundle(pdfData: data))
        let document = try await repository.document(for: publication())
        XCTAssertEqual(document.pageCount, 2)

        let missing = PublicationRepository(bundle: try fixtureBundle())
        do {
            _ = try await missing.document(for: publication())
            XCTFail("Missing files must fail")
        } catch PublicationError.missingPDF {}

        let invalid = PublicationRepository(bundle: try fixtureBundle(pdfData: Data("not a PDF".utf8)))
        do {
            _ = try await invalid.document(for: publication())
            XCTFail("Invalid PDFs must fail")
        } catch PublicationError.invalidPDF {}
    }

    func testRejectsInsecureAndTokenBearingRemoteURLs() async throws {
        let repository = PublicationRepository(bundle: try fixtureBundle())
        for raw in ["http://example.test/issue.pdf", "https://example.test/issue.pdf?token=secret"] {
            let item = publication(bundledPDF: nil, remoteURL: try XCTUnwrap(URL(string: raw)))
            do {
                _ = try await repository.document(for: item)
                XCTFail("Unsafe URL must fail")
            } catch PublicationError.invalidURL {}
        }
    }

    func testSavedAndPageProgressPersistAndCanBeRemoved() throws {
        let suite = "publication-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let item = publication()
        let library = PublicationLibrary(defaults: defaults)
        library.toggleSaved(item)
        library.setPage(3, for: item)
        let reloaded = PublicationLibrary(defaults: defaults)
        XCTAssertTrue(reloaded.isSaved(item))
        XCTAssertEqual(reloaded.page(for: item), 3)
        reloaded.toggleSaved(item)
        XCTAssertFalse(PublicationLibrary(defaults: defaults).isSaved(item))
    }

    func testSearchAndIssueYearFilters() throws {
        let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 1)))
        let match = publication(title: "Future of Mentorship", date: date)
        let other = publication(title: "Leadership", issue: "Week 13", date: date)
        XCTAssertEqual(PublicationLibrary.filtered([match, other], search: "MENTOR", issue: "Week 12", year: 2024), [match])
        XCTAssertTrue(PublicationLibrary.filtered([match], search: "", issue: nil, year: 2025).isEmpty)
    }
}
