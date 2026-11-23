import SwiftUI
import PDFKit

struct PublicationReader: View {
    let publication: Publication
    let library: PublicationLibrary
    let repository: PublicationRepository
    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var errorMessage: String?
    @State private var currentPage = 0
    @State private var requestedPage: Int?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    PDFDocumentView(document: document, requestedPage: $requestedPage) { page in
                        currentPage = page
                        library.setPage(page, for: publication)
                    }
                    .accessibilityLabel("Publication pages. Pinch to zoom and scroll to read.")
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else if isLoading {
                    ProgressView("Loading publication")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ROCKSColor.background)
            .navigationTitle(publication.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        library.toggleSaved(publication)
                    } label: {
                        Image(systemName: library.isSaved(publication) ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityLabel(library.isSaved(publication) ? "Remove saved publication" : "Save publication")
                }
                if let document {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            requestedPage = max(0, currentPage - 1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(currentPage == 0)
                        .accessibilityLabel("Previous page")
                        Spacer()
                        Text("Page \(currentPage + 1) of \(document.pageCount)")
                            .font(.subheadline.monospacedDigit())
                            .accessibilityLabel("Page \(currentPage + 1) of \(document.pageCount)")
                        Spacer()
                        Button {
                            requestedPage = min(document.pageCount - 1, currentPage + 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(currentPage >= document.pageCount - 1)
                        .accessibilityLabel("Next page")
                    }
                }
            }
            .tint(ROCKSColor.goldText)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loaded = try await repository.document(for: publication)
            let page = min(library.page(for: publication), loaded.pageCount - 1)
            currentPage = page
            requestedPage = page
            document = loaded
        } catch is CancellationError {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to open this publication."
        }
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var requestedPage: Int?
    let onPageChanged: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPageChanged: onPageChanged)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = document
        let coordinator = context.coordinator
        coordinator.observer = NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged, object: view, queue: .main
        ) { [weak view, weak coordinator] _ in
            guard let view, let page = view.currentPage, let document = view.document else { return }
            let index = document.index(for: page)
            guard index < document.pageCount else { return }
            DispatchQueue.main.async {
                coordinator?.onPageChanged(index)
            }
        }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.onPageChanged = onPageChanged
        if view.document !== document {
            view.document = document
        }
        if let requestedPage, let page = document.page(at: requestedPage) {
            view.go(to: page)
            DispatchQueue.main.async {
                if self.requestedPage == requestedPage {
                    self.requestedPage = nil
                }
            }
        }
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        if let observer = coordinator.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    final class Coordinator {
        var observer: NSObjectProtocol?
        var onPageChanged: (Int) -> Void

        init(onPageChanged: @escaping (Int) -> Void) {
            self.onPageChanged = onPageChanged
        }
    }
}
