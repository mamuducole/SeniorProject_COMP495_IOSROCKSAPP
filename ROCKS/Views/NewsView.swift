import SwiftUI
import PDFKit

struct NewsView: View {
    let showsSavedFirst: Bool
    private let articles = NewsArticle.examples.sorted { $0.publishedAt > $1.publishedAt }
    private let repository = PublicationRepository()
    @State private var library = PublicationLibrary()
    @State private var publications: [Publication] = []
    @State private var search = ""
    @State private var selectedIssue: String?
    @State private var selectedYear: Int?
    @State private var loadError: String?
    @State private var isLoading = true

    init(showsSavedFirst: Bool = false) {
        self.showsSavedFirst = showsSavedFirst
    }

    private var filtered: [Publication] {
        PublicationLibrary.filtered(publications, search: search, issue: selectedIssue, year: selectedYear)
    }

    private var years: [Int] {
        Array(Set(publications.compactMap(\.publicationYear))).sorted(by: >)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                filters
                if isLoading {
                    LoadingView()
                } else if let loadError {
                    ErrorStateView(message: loadError) { load() }
                } else {
                    if publications.isEmpty {
                        EmptyStateView(
                            title: "No publications available",
                            systemImage: "books.vertical",
                            message: "Authorized publications will appear here when they are added."
                        )
                    } else if filtered.isEmpty {
                        EmptyStateView(title: "No matching publications", systemImage: "magnifyingglass", message: "Try another title or filter.")
                    }
                    if showsSavedFirst {
                        publicationSection("Saved Publications", items: filtered.filter { library.isSaved($0) })
                    }
                    publicationSection("Latest Publications", items: Array(filtered.prefix(3)))
                    publicationSection("ROCKS REFRESH", items: filtered.filter(\.isRefresh))
                    publicationSection("Previous Issues", items: Array(filtered.dropFirst(3)))
                    if !showsSavedFirst {
                        publicationSection("Saved Publications", items: filtered.filter { library.isSaved($0) })
                    }
                }
                newsSection
            }
            .padding(20)
        }
        .background(ROCKSColor.background)
        .navigationTitle("News & Publications")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ROCKSLogoHeader(size: .compact, showsTagline: false)
            Text("News & Publications")
                .font(ROCKSFont.titleSmall)
                .foregroundStyle(ROCKSColor.onDarkText)
            Text("Read and revisit publications from the ROCKS community.")
                .font(.subheadline)
                .foregroundStyle(ROCKSColor.onDarkText.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(LinearGradient.rocksBranded, in: RoundedRectangle(cornerRadius: 20))
    }

    private var filters: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ROCKSColor.subtleText)
                TextField("Search publications by title", text: $search)
                    .accessibilityLabel("Search publications by title")
            }
            .padding(12)
            .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Menu {
                    Button("All issues") { selectedIssue = nil }
                    ForEach(Array(Set(publications.compactMap(\.issue))).sorted(), id: \.self) { issue in
                        Button(issue) { selectedIssue = issue }
                    }
                } label: {
                    Label(selectedIssue ?? "All issues", systemImage: "line.3.horizontal.decrease.circle")
                }
                Spacer()
                Menu {
                    Button("All dates") { selectedYear = nil }
                    ForEach(years, id: \.self) { year in
                        Button(String(year)) { selectedYear = year }
                    }
                } label: {
                    Label(selectedYear.map(String.init) ?? "All dates", systemImage: "calendar")
                }
            }
            .font(.subheadline)
            .foregroundStyle(ROCKSColor.goldText)
        }
    }

    private func publicationSection(_ title: String, items: [Publication]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(ROCKSColor.primaryText)
            if items.isEmpty {
                Text(title == "Saved Publications" ? "Save a publication to find it here." : "No publications in this section.")
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
            } else {
                ForEach(items) { publication in
                    NavigationLink {
                        PublicationDetailView(publication: publication, library: library, repository: repository)
                    } label: {
                        PublicationCard(publication: publication, library: library, repository: repository)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("News")
                .font(.title3.weight(.bold))
            Text("Sample articles")
                .font(.caption)
                .foregroundStyle(ROCKSColor.subtleText)
            ForEach(articles) { article in
                NavigationLink {
                    NewsDetailView(article: article)
                } label: {
                    ROCKSCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.headline).font(.headline)
                            Text(article.summary).font(.subheadline).foregroundStyle(ROCKSColor.subtleText)
                            Text(article.publishedAt, format: .dateTime.month(.abbreviated).day().year())
                                .font(.caption)
                                .foregroundStyle(ROCKSColor.goldText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        do {
            publications = try repository.fetchPublications()
            loadError = nil
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? "Unable to load publications."
        }
    }
}

private struct PublicationCard: View {
    let publication: Publication
    let library: PublicationLibrary
    let repository: PublicationRepository

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PublicationCover(publication: publication, repository: repository)
                .frame(width: 80, height: 110)
            VStack(alignment: .leading, spacing: 5) {
                if publication.isRefresh {
                    Text("ROCKS REFRESH")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ROCKSColor.goldText)
                }
                Text(publication.title)
                    .font(.headline)
                    .foregroundStyle(ROCKSColor.primaryText)
                if let issue = publication.issue {
                    Text(issue).font(.caption.weight(.medium)).foregroundStyle(ROCKSColor.goldText)
                }
                if let date = publication.publishedAt {
                    Text(date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption).foregroundStyle(ROCKSColor.subtleText)
                }
                Text(publication.description)
                    .font(.subheadline)
                    .foregroundStyle(ROCKSColor.subtleText)
                    .lineLimit(2)
                if library.isSaved(publication) {
                    Label("Saved", systemImage: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(ROCKSColor.goldText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ROCKSColor.cardBackground, in: RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: ROCKSTheme.cornerRadius).stroke(ROCKSColor.divider))
    }
}

private struct PublicationCover: View {
    let publication: Publication
    let repository: PublicationRepository

    var body: some View {
        Group {
            if let url = repository.bundledURL(for: publication),
               let page = PDFDocument(url: url)?.page(at: 0) {
                Image(uiImage: page.thumbnail(of: CGSize(width: 200, height: 280), for: .mediaBox))
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ROCKSColor.charcoal)
                    .overlay {
                        Image(systemName: "doc.richtext")
                            .font(.title)
                            .foregroundStyle(ROCKSColor.goldLight)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

private struct PublicationDetailView: View {
    let publication: Publication
    let library: PublicationLibrary
    let repository: PublicationRepository
    @State private var isReading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PublicationCover(publication: publication, repository: repository)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                Text(publication.title).font(ROCKSFont.titleSmall)
                if let issue = publication.issue {
                    Text(issue).font(.subheadline.weight(.semibold)).foregroundStyle(ROCKSColor.goldText)
                }
                if let date = publication.publishedAt {
                    Text(date, format: .dateTime.month(.wide).day().year())
                        .font(.subheadline).foregroundStyle(ROCKSColor.subtleText)
                }
                Text(publication.description).font(.body)
                Button {
                    isReading = true
                } label: {
                    Label(library.page(for: publication) > 0 ? "Continue Reading" : "Read Publication", systemImage: "book.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ROCKSColor.goldText)
                Button {
                    library.toggleSaved(publication)
                } label: {
                    Label(library.isSaved(publication) ? "Remove from Saved" : "Save for Later",
                          systemImage: library.isSaved(publication) ? "bookmark.fill" : "bookmark")
                }
                .tint(ROCKSColor.goldText)
            }
            .padding(20)
        }
        .background(ROCKSColor.background)
        .navigationTitle("Publication")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isReading) {
            PublicationReader(publication: publication, library: library, repository: repository)
        }
    }
}

struct NewsDetailView: View {
    let article: NewsArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(article.headline)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(ROCKSColor.primaryText)
                Text(article.publishedAt, format: .dateTime.month(.wide).day().year())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ROCKSColor.goldText)
                Text(article.body)
                    .font(.body)
                    .foregroundStyle(ROCKSColor.primaryText)
            }
            .padding()
        }
        .background(ROCKSColor.background)
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
    }
}
