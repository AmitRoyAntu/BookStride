//
//  JournalView.swift
//  BookStride
//
//  Reading journal screen for reflections, notes, and favorite quotes.
//

import SwiftUI
import SwiftData

public enum JournalFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"
    case notes = "Notes"
    case quotes = "Quotes"
    case reflections = "Reflections"
    
    public var id: String { rawValue }
}

public struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var allEntries: [JournalEntry]
    @Query(sort: \Book.title)
    private var allBooks: [Book]
    
    @State private var selectedFilter: JournalFilter = .all
    @State private var selectedBookId: UUID? = nil
    @State private var searchText: String = ""
    @State private var showingAddSheet: Bool = false
    
    public init() {}
    
    private var selectedBookTitle: String {
        if let id = selectedBookId, let book = allBooks.first(where: { $0.id == id }) {
            return book.title
        }
        return "All Books"
    }
    
    private var filteredEntries: [JournalEntry] {
        var list = allEntries
        
        switch selectedFilter {
        case .all:
            break
        case .favorites:
            list = list.filter { $0.isFavorite }
        case .notes:
            list = list.filter { $0.entryType == .note }
        case .quotes:
            list = list.filter { $0.entryType == .quote }
        case .reflections:
            list = list.filter { $0.entryType == .reflection }
        }
        
        if let bookId = selectedBookId {
            list = list.filter { $0.book?.id == bookId }
        }
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.content.lowercased().contains(query) ||
                ($0.book?.title.lowercased().contains(query) ?? false)
            }
        }
        
        return list
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Filter bar: Type tabs & Book filter dropdown
                HStack(alignment: .center, spacing: 12) {
                    // Type Filter Tabs (Responsive horizontal scroll)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(JournalFilter.allCases) { filter in
                                let isSelected = selectedFilter == filter
                                Button {
                                    selectedFilter = filter
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .foregroundColor(isSelected ? .white : BookStrideTheme.deepCharcoal)
                                        .padding(.horizontal, 16)
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
                        }
                    }
                    
                    Spacer(minLength: 4)
                    
                    // Book Filter Menu
                    Menu {
                        Button {
                            selectedBookId = nil
                        } label: {
                            if selectedBookId == nil {
                                Label("All Books", systemImage: "checkmark")
                            } else {
                                Text("All Books")
                            }
                        }
                        
                        if !allBooks.isEmpty {
                            Divider()
                            ForEach(allBooks) { book in
                                Button {
                                    selectedBookId = book.id
                                } label: {
                                    if selectedBookId == book.id {
                                        Label(book.title, systemImage: "checkmark")
                                    } else {
                                        Text(book.title)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: selectedBookId == nil ? "books.vertical" : "book.fill")
                                .font(.caption)
                                .foregroundColor(selectedBookId != nil ? BookStrideTheme.forestGreen : BookStrideTheme.mutedSlate)
                            
                            Text(selectedBookTitle)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                                .foregroundColor(selectedBookId != nil ? BookStrideTheme.forestGreen : BookStrideTheme.deepCharcoal)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(BookStrideTheme.cardLight)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedBookId != nil ? BookStrideTheme.forestGreen : BookStrideTheme.borderLight, lineWidth: 1)
                        )
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 24)
                
                // Content
                if allEntries.isEmpty {
                    VStack {
                        Spacer(minLength: 40)
                        EmptyStateCard(
                            iconName: "quote.opening",
                            title: "Reading Journal is Empty",
                            message: "Capture resonant quotes, passages, and your personal reflections while reading.",
                            buttonTitle: "Write First Note",
                            action: { showingAddSheet = true }
                        )
                        .padding(.horizontal, 24)
                        Spacer(minLength: 40)
                    }
                } else if filteredEntries.isEmpty {
                    EmptyStateCard(
                        iconName: "magnifyingglass",
                        title: "No Matching Entries",
                        message: "No journal entries matched your current filter or search criteria.",
                        buttonTitle: (selectedBookId != nil || selectedFilter != .all || !searchText.isEmpty) ? "Clear Filters" : nil,
                        action: {
                            selectedFilter = .all
                            selectedBookId = nil
                            searchText = ""
                        }
                    )
                    .padding(.horizontal, 24)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredEntries) { entry in
                            NavigationLink {
                                JournalDetailView(entry: entry)
                            } label: {
                                JournalCardView(entry: entry, onDelete: {
                                    modelContext.delete(entry)
                                    try? modelContext.save()
                                })
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
        .navigationTitle("Reading Journal")
        .searchable(text: $searchText, prompt: "Search notes, quotes, or books")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Entry", systemImage: "plus")
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditJournalEntrySheet()
        }
    }
}

