//
//  JournalCardView.swift
//  BookStride
//
//  Stylized reading journal entry card formatted for notes and quotes.
//

import SwiftUI
import SwiftData

public struct JournalCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: JournalEntry
    public var onDelete: () -> Void
    
    @State private var showingEditSheet: Bool = false
    @State private var showingDeleteAlert: Bool = false
    
    public init(entry: JournalEntry, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onDelete = onDelete
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with type badge, book link, and favorite star
            HStack(spacing: 8) {
                Label(entry.entryType.rawValue, systemImage: entry.entryType.iconName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(entry.entryType == .quote ? BookStrideTheme.streakAmber : BookStrideTheme.forestGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (entry.entryType == .quote ? BookStrideTheme.streakAmber : BookStrideTheme.forestGreen).opacity(0.12)
                    )
                    .cornerRadius(8)
                
                if let book = entry.book {
                    Text(book.title)
                        .font(.caption.weight(.medium))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                        .lineLimit(1)
                }
                
                if let page = entry.pageNumber {
                    Text("• p. \(page)")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                Spacer()
                
                // Favorite Button
                Button {
                    entry.isFavorite.toggle()
                    entry.updatedAt = Date()
                    try? modelContext.save()
                } label: {
                    Image(systemName: entry.isFavorite ? "star.fill" : "star")
                        .foregroundColor(entry.isFavorite ? BookStrideTheme.streakAmber : BookStrideTheme.mutedSlate)
                        .font(.subheadline)
                }
            }
            
            // Content
            if entry.entryType == .quote {
                HStack(alignment: .top, spacing: 10) {
                    Text("“")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundColor(BookStrideTheme.streakAmber.opacity(0.6))
                        .offset(y: -4)
                    
                    Text(entry.content)
                        .font(.system(.body, design: .serif))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                        .italic()
                        .lineSpacing(4)
                }
                .padding(.horizontal, 4)
            } else {
                Text(entry.content)
                    .font(.body)
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .lineSpacing(3)
            }
            
            // Footer date
            HStack {
                Spacer()
                Text(Formatters.formatDate(entry.createdAt, style: .mediumDate))
                    .font(.caption2)
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
        }
        .padding(18)
        .BookStrideCardStyle()
        .contextMenu {
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
                Label(entry.isFavorite ? "Unfavorite" : "Favorite", systemImage: "star")
            }
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete Entry", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditJournalEntrySheet(entryToEdit: entry)
        }
        .confirmationDialog("Delete Journal Entry?", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
            Button("Delete Entry", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

