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
    case quotes = "Quotes"
    case notes = "Notes"
    
    public var id: String { rawValue }
}

public struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var allEntries: [JournalEntry]
    
    @State private var selectedFilter: JournalFilter = .all
    @State private var searchText: String = ""
    @State private var showingAddSheet: Bool = false
    
    public init() {}
    
    private var filteredEntries: [JournalEntry] {
        var list = allEntries
        
        switch selectedFilter {
        case .all:
            break
        case .favorites:
            list = list.filter { $0.isFavorite }
        case .quotes:
            list = list.filter { $0.entryType == .quote }
        case .notes:
            list = list.filter { $0.entryType == .note }
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
                // Filter Tabs (Responsive horizontal scroll)
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
                    .padding(.horizontal, 24)
                }
                
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
                        message: "No journal entries matched your current filter or search."
                    )
                    .padding(.horizontal, 24)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredEntries) { entry in
                            JournalCardView(entry: entry, onDelete: {
                                modelContext.delete(entry)
                                try? modelContext.save()
                            })
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

