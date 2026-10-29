//
//  LibraryView.swift
//  BookStride
//
//  iPad library view featuring responsive cover grid, filters, sorting, and search.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public enum LibrarySortOption: String, CaseIterable, Identifiable {
    case recentlyAdded = "Recently Added"
    case title = "Title (A-Z)"
    case author = "Author (A-Z)"
    case progress = "Progress"
    
    public var id: String { rawValue }
}

public struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allBooks: [Book]
    
    @State private var selectedStatusFilter: ReadingStatus? = .currentlyReading
    @State private var sortOption: LibrarySortOption = .recentlyAdded
    @State private var searchText: String = ""
    @State private var showingAddBookSheet: Bool = false
    @State private var showingImportPicker: Bool = false
    @State private var importedMetadataToReview: ExtractedBookMetadata?
    @State private var importErrorMessage: String?
    @State private var showingImportErrorAlert: Bool = false
    @State private var bookToDelete: Book?
    @State private var showingDeleteConfirmation: Bool = false
    
    public init() {}
    
    private var filteredAndSortedBooks: [Book] {
        var list = allBooks
        
        // Filter by Status
        if let filter = selectedStatusFilter {
            list = list.filter { $0.status == filter }
        }
        
        // Filter by Search Query
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(query) ||
                $0.author.lowercased().contains(query)
            }
        }
        
        // Sort
        switch sortOption {
        case .recentlyAdded:
            list.sort { $0.createdAt > $1.createdAt }
        case .title:
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            list.sort { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
        case .progress:
            list.sort { $0.progressFraction > $1.progressFraction }
        }
        
        return list
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Filter Pills & Sort Menu (Responsive with smooth horizontal scrolling)
                HStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            allFilterButton
                            filterButton(title: "Currently Reading", status: .currentlyReading)
                            filterButton(title: "Want to Read", status: .wantToRead)
                            filterButton(title: "Finished", status: .finished)
                        }
                        .padding(.leading, 24)
                        .padding(.trailing, 8)
                    }
                    
                    // Trailing Sort Menu
                    sortMenuButton
                        .padding(.trailing, 24)
                }
                
                // Book Grid or Empty State
                if filteredAndSortedBooks.isEmpty {
                    VStack {
                        Spacer(minLength: 40)
                        EmptyStateCard(
                            iconName: "books.vertical",
                            title: emptyStateTitle,
                            message: emptyStateMessage,
                            buttonTitle: "Add Book",
                            action: { showingAddBookSheet = true }
                        )
                        .padding(.horizontal, 24)
                        Spacer(minLength: 40)
                    }
                } else {
                    LazyVGrid(columns: LayoutConstants.libraryColumns, spacing: 28) {
                        ForEach(filteredAndSortedBooks) { book in
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                BookCardView(
                                    book: book,
                                    onMarkFinished: { markBookAsFinished(book) },
                                    onDelete: {
                                        bookToDelete = book
                                        showingDeleteConfirmation = true
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .padding(.top, 16)
        }
        .BookStrideBackground()
        .navigationTitle("Library")
        .searchable(text: $searchText, prompt: "Search by title or author")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingAddBookSheet = true
                    } label: {
                        Label("Add Book Manually", systemImage: "plus")
                    }
                    
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import Book (EPUB, PDF)…", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
        }
        .sheet(isPresented: $showingAddBookSheet) {
            AddEditBookSheet()
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.pdf, .epub],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }
                guard selectedURL.startAccessingSecurityScopedResource() else {
                    importErrorMessage = "Access to the selected file was denied by iPadOS security."
                    showingImportErrorAlert = true
                    return
                }
                defer { selectedURL.stopAccessingSecurityScopedResource() }
                
                do {
                    let metadata = try BookImportService.extractMetadata(from: selectedURL)
                    importedMetadataToReview = metadata
                } catch {
                    importErrorMessage = error.localizedDescription
                    showingImportErrorAlert = true
                }
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showingImportErrorAlert = true
            }
        }
        .sheet(item: $importedMetadataToReview) { metadata in
            ImportBookReviewSheet(metadata: metadata)
        }
        .alert("Import Failed", isPresented: $showingImportErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "An unknown error occurred while importing.")
        }
        .confirmationDialog(
            "Delete Book?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: bookToDelete
        ) { book in
            Button("Delete \"\(book.title)\"", role: .destructive) {
                deleteBook(book)
            }
            Button("Cancel", role: .cancel) {}
        } message: { book in
            Text("This will permanently delete this book, its reading sessions, and associated journal notes.")
        }
    }
    
    private var allFilterButton: some View {
        let isSelected = selectedStatusFilter == nil
        let count = allBooks.count
        
        return Button {
            selectedStatusFilter = nil
        } label: {
            Text("All (\(count))")
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(isSelected ? .white : BookStrideTheme.deepCharcoal)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? BookStrideTheme.forestGreen : BookStrideTheme.cardLight)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(BookStrideTheme.borderLight, lineWidth: isSelected ? 0 : 1)
                )
        }
        .fixedSize(horizontal: true, vertical: false)
    }
    
    private func filterButton(title: String, status: ReadingStatus) -> some View {
        let isSelected = selectedStatusFilter == status
        let count = allBooks.filter { $0.status == status }.count
        
        return Button {
            selectedStatusFilter = status
        } label: {
            Text("\(title) (\(count))")
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(isSelected ? .white : BookStrideTheme.deepCharcoal)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? BookStrideTheme.forestGreen : BookStrideTheme.cardLight)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(BookStrideTheme.borderLight, lineWidth: isSelected ? 0 : 1)
                )
        }
        .fixedSize(horizontal: true, vertical: false)
    }
    
    private var sortMenuButton: some View {
        Menu {
            Picker("Sort By", selection: $sortOption) {
                ForEach(LibrarySortOption.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                Text(sortOption.rawValue)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.callout.weight(.medium))
            .foregroundColor(BookStrideTheme.deepCharcoal)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(BookStrideTheme.cardLight)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(BookStrideTheme.borderLight, lineWidth: 1)
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }
    
    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No Matching Books"
        } else if let filter = selectedStatusFilter {
            return "No \(filter.rawValue) Books"
        } else {
            return "Your Library is Empty"
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No books matched \"\(searchText)\". Try another query."
        } else if selectedStatusFilter == .currentlyReading {
            return "You have no books marked as currently reading. Pick a book from your want-to-read shelf or add a new one."
        } else if selectedStatusFilter == .finished {
            return "Finished books will appear here once you complete them."
        } else {
            return "Add your first book to track reading sessions, notes, and milestones."
        }
    }
    
    private func markBookAsFinished(_ book: Book) {
        book.status = .finished
        book.finishDate = Date()
        if let total = book.totalPages {
            book.currentPage = total
        }
        book.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func deleteBook(_ book: Book) {
        modelContext.delete(book)
        try? modelContext.save()
    }
}

