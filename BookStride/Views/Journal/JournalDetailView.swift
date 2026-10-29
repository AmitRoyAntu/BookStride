//
//  JournalDetailView.swift
//  BookStride
//
//  Dedicated full detail view for reading journal entries, notes, quotes, and reflections.
//

import SwiftUI
import SwiftData

public struct JournalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var entry: JournalEntry
    
    @State private var showingEditSheet: Bool = false
    @State private var showingDeleteAlert: Bool = false
    
    public init(entry: JournalEntry) {
        self.entry = entry
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header: Type badge, Favorite toggle & Timestamps
                HStack(alignment: .center) {
                    Label(entry.entryType.rawValue, systemImage: entry.entryType.iconName)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(typeColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(typeColor.opacity(0.12))
                        .cornerRadius(12)
                    
                    Spacer()
                    
                    // Favorite Toggle
                    Button {
                        entry.isFavorite.toggle()
                        entry.updatedAt = Date()
                        try? modelContext.save()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: entry.isFavorite ? "star.fill" : "star")
                                .foregroundColor(entry.isFavorite ? BookStrideTheme.streakAmber : BookStrideTheme.mutedSlate)
                            Text(entry.isFavorite ? "Favorited" : "Favorite")
                                .font(.caption.weight(.medium))
                                .foregroundColor(BookStrideTheme.mutedSlate)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(BookStrideTheme.cardLight)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BookStrideTheme.borderLight, lineWidth: 1))
                    }
                }
                
                // Associated Book Card (if linked)
                if let book = entry.book {
                    NavigationLink {
                        BookDetailView(book: book)
                    } label: {
                        HStack(spacing: 16) {
                            BookCoverThumbnail(
                                imageData: book.coverImageData,
                                title: book.title,
                                author: book.author,
                                colorHex: book.coverColorHex,
                                iconName: book.coverIcon,
                                width: 50,
                                height: 75,
                                cornerRadius: 6
                            )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.title)
                                    .font(.system(.headline, design: .serif, weight: .semibold))
                                    .foregroundColor(BookStrideTheme.deepCharcoal)
                                    .lineLimit(2)
                                
                                if !book.author.isEmpty {
                                    Text("by \(book.author)")
                                        .font(.subheadline)
                                        .foregroundColor(BookStrideTheme.mutedSlate)
                                }
                                
                                if let page = entry.pageNumber, page >= 0 {
                                    Text("Passage from page \(page)")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(BookStrideTheme.forestGreen)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                        }
                        .padding(16)
                        .BookStrideCardStyle()
                    }
                    .buttonStyle(.plain)
                } else if let page = entry.pageNumber, page >= 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark")
                            .foregroundColor(BookStrideTheme.forestGreen)
                        Text("Page \(page)")
                            .font(.caption.weight(.medium))
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(BookStrideTheme.cardLight)
                    .cornerRadius(10)
                }
                
                // Formatted Content Area
                VStack(alignment: .leading, spacing: 16) {
                    if entry.entryType == .quote {
                        // Quote styling: Large quotation mark, serif typography, italicized
                        VStack(alignment: .leading, spacing: 12) {
                            Text("“")
                                .font(.system(size: 64, weight: .bold, design: .serif))
                                .foregroundColor(BookStrideTheme.streakAmber.opacity(0.5))
                                .frame(height: 32, alignment: .topLeading)
                            
                            Text(entry.content)
                                .font(.system(.title3, design: .serif))
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                                .italic()
                                .lineSpacing(6)
                                .padding(.horizontal, 6)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(BookStrideTheme.cardLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(BookStrideTheme.streakAmber.opacity(0.3), lineWidth: 1.5)
                        )
                    } else if entry.entryType == .reflection {
                        // Reflection styling: Distinct thought card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(BookStrideTheme.forestGreen)
                                Text("Reading Reflection")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(BookStrideTheme.forestGreen)
                                    .textCase(.uppercase)
                            }
                            
                            Text(entry.content)
                                .font(.body)
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                                .lineSpacing(5)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .BookStrideCardStyle()
                    } else {
                        // Note styling
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.content)
                                .font(.body)
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                                .lineSpacing(5)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .BookStrideCardStyle()
                    }
                }
                
                // Timestamps & Metadata Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Created")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        Spacer()
                        Text(Formatters.formatDate(entry.createdAt, style: .dateTime))
                            .font(.caption.weight(.medium))
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                    }
                    
                    if entry.updatedAt != entry.createdAt {
                        Divider()
                        HStack {
                            Text("Last Modified")
                                .font(.caption)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                            Spacer()
                            Text(Formatters.formatDate(entry.updatedAt, style: .dateTime))
                                .font(.caption.weight(.medium))
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                        }
                    }
                }
                .padding(16)
                .BookStrideCardStyle()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .BookStrideBackground()
        .navigationTitle(entry.entryType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Entry", systemImage: "pencil")
                    }
                    
                    Button {
                        entry.isFavorite.toggle()
                        entry.updatedAt = Date()
                        try? modelContext.save()
                    } label: {
                        Label(entry.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: entry.isFavorite ? "star.slash" : "star")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditJournalEntrySheet(entryToEdit: entry, associatedBook: entry.book)
        }
        .confirmationDialog(
            "Delete Journal Entry?",
            isPresented: $showingDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Delete Entry", role: .destructive) {
                modelContext.delete(entry)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this journal entry. This action cannot be undone.")
        }
    }
    
    private var typeColor: Color {
        switch entry.entryType {
        case .quote: return BookStrideTheme.streakAmber
        case .reflection: return BookStrideTheme.forestGreen
        case .note: return BookStrideTheme.forestGreen
        }
    }
}
