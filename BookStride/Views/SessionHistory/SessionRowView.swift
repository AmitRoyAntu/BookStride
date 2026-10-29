//
//  SessionRowView.swift
//  BookStride
//
//  List row representation of a past reading session with duration and page delta.
//

import SwiftUI
import SwiftData

public struct SessionRowView: View {
    @Environment(\.modelContext) private var modelContext
    public var session: ReadingSession
    
    @State private var showingEditSheet: Bool = false
    @State private var showingDeleteAlert: Bool = false
    
    public init(session: ReadingSession) {
        self.session = session
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Book cover thumbnail or generic session icon
            if let book = session.book {
                BookCoverThumbnail(
                    imageData: book.coverImageData,
                    title: book.title,
                    author: book.author,
                    colorHex: book.coverColorHex,
                    iconName: book.coverIcon,
                    width: 44,
                    height: 66,
                    cornerRadius: 4
                )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(BookStrideTheme.warmBeige.opacity(0.4))
                        .frame(width: 44, height: 66)
                    Image(systemName: "timer")
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
            
            // Session Info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.book?.title ?? "Unassigned Session")
                    .font(.headline)
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(Formatters.formatDate(session.startedAt, style: .dateTime))
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                    
                    if let pages = session.pagesRead, pages > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        Text("\(pages) pages read")
                            .font(.caption.weight(.medium))
                            .foregroundColor(BookStrideTheme.forestGreen)
                    }
                }
                
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.deepCharcoal.opacity(0.8))
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Duration Badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.formatDuration(seconds: session.activeDurationSeconds, style: .short))
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.forestGreen)
                
                if session.pausedDurationSeconds > 0 {
                    Text("Paused \(Formatters.formatDuration(seconds: session.pausedDurationSeconds, style: .short))")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
            }
        }
        .padding(14)
        .BookStrideCardStyle()
        .contextMenu {
            Button {
                showingEditSheet = true
            } label: {
                Label("Edit Session", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete Session", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ManualSessionSheet(sessionToEdit: session)
        }
        .confirmationDialog("Delete Reading Session?", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
            Button("Delete Session", role: .destructive) {
                modelContext.delete(session)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This session's reading time will be removed from your streaks and analytics.")
        }
    }
}

