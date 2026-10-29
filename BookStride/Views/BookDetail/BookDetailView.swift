//
//  BookDetailView.swift
//  BookStride
//
//  Comprehensive book detail screen for iPad with session history, stats, and journal entries.
//

import SwiftUI
import SwiftData

public struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var timerService = ReadingTimerService.shared
    
    @Bindable var book: Book
    
    @State private var showingEditSheet: Bool = false
    @State private var showingProgressSheet: Bool = false
    @State private var showingAddJournalSheet: Bool = false
    @State private var showingActiveSession: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var showingConflictAlert: Bool = false
    
    public init(book: Book) {
        self.book = book
    }
    
    private var completedSessions: [ReadingSession] {
        book.sessions
            .filter { $0.status == .completed }
            .sorted { $0.startedAt > $1.startedAt }
    }
    
    private var totalSecondsRead: Int {
        completedSessions.reduce(0) { $0 + $1.activeDurationSeconds }
    }
    
    private var estimatedCompletionString: String? {
        guard let date = book.estimatedCompletionDate() else { return nil }
        return Formatters.formatDate(date, style: .mediumDate)
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // 1. Hero Book Banner
                heroHeader
                
                // 2. Action Controls
                actionControls
                
                // 3. Reading Progress & Speed Insights
                progressAndInsightsSection
                
                // 4. Book Description
                if let desc = book.bookDescription, !desc.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "About the Book")
                        Text(desc)
                            .font(.body)
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                            .lineSpacing(4)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .BookStrideCardStyle()
                    }
                }
                
                // 5. Notes & Quotes for this Book
                notesAndQuotesSection
                
                // 6. Session History for this Book
                sessionsHistorySection
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .BookStrideBackground()
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Book", systemImage: "pencil")
                    }
                    
                    if book.status != .finished {
                        Button {
                            markFinished()
                        } label: {
                            Label("Mark as Finished", systemImage: "checkmark.circle")
                        }
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Book", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditBookSheet(bookToEdit: book)
        }
        .sheet(isPresented: $showingProgressSheet) {
            UpdateProgressSheet(book: book)
        }
        .sheet(isPresented: $showingAddJournalSheet) {
            AddEditJournalEntrySheet(associatedBook: book)
        }
        .sheet(isPresented: $showingActiveSession) {
            ActiveSessionView(
                timerService: timerService,
                associatedBook: book,
                onFinish: { endPage, notes in
                    saveFinishedSession(endPage: endPage, notes: notes)
                }
            )
        }
        .alert("Session in Progress", isPresented: $showingConflictAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A reading session is already active for \"\(timerService.activeState?.bookTitle ?? "another book")\". Please pause or finish that session before starting a new one.")
        }
        .confirmationDialog("Delete Book?", isPresented: $showingDeleteAlert, titleVisibility: .visible) {
            Button("Delete \"\(book.title)\"", role: .destructive) {
                modelContext.delete(book)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting this book will also remove its associated reading sessions and notes.")
        }
    }
    
    // MARK: - Subviews
    
    private var heroHeader: some View {
        HStack(alignment: .top, spacing: 32) {
            BookCoverThumbnail(
                imageData: book.coverImageData,
                title: book.title,
                author: book.author,
                colorHex: book.coverColorHex,
                iconName: book.coverIcon,
                width: LayoutConstants.bookDetailCoverWidth,
                height: LayoutConstants.bookDetailCoverHeight,
                cornerRadius: 12
            )
            
            VStack(alignment: .leading, spacing: 14) {
                // Status pill
                HStack {
                    Label(book.status.rawValue, systemImage: book.status.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(BookStrideTheme.forestGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(BookStrideTheme.forestGreen.opacity(0.12))
                        .cornerRadius(12)
                    
                    Spacer()
                    
                    // Star rating
                    if let rating = book.rating, rating > 0 {
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(BookStrideTheme.streakAmber)
                            }
                        }
                    }
                }
                
                Text(book.title)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .lineLimit(3)
                
                if !book.author.isEmpty {
                    Text("by \(book.author)")
                        .font(.title3.weight(.medium))
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                Spacer()
                
                // Key metrics row
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reading Time")
                            .font(.caption2)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        Text(Formatters.formatDuration(seconds: totalSecondsRead, style: .short))
                            .font(.headline.weight(.bold))
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                    }
                    
                    Divider().frame(height: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sessions")
                            .font(.caption2)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        Text("\(completedSessions.count)")
                            .font(.headline.weight(.bold))
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                    }
                    
                    if let firstDate = book.firstReadingDate {
                        Divider().frame(height: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Started")
                                .font(.caption2)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                            Text(Formatters.formatDate(firstDate, style: .shortDate))
                                .font(.headline.weight(.bold))
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                        }
                    }
                }
                .padding()
                .BookStrideCardStyle()
            }
        }
        .padding(.vertical, 8)
    }
    
    private var actionControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Start Reading Button
                Button {
                    if timerService.activeState?.bookId == book.id {
                        showingActiveSession = true
                    } else {
                        let success = timerService.startSession(
                            bookId: book.id,
                            bookTitle: book.title,
                            startPage: book.currentPage
                        )
                        if success {
                            showingActiveSession = true
                        } else {
                            showingConflictAlert = true
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: timerService.activeState?.bookId == book.id ? "hourglass" : "play.circle.fill")
                        Text(timerService.activeState?.bookId == book.id ? "View Active Session" : "Start Reading")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(BookStrideTheme.forestGreen)
                    .cornerRadius(12)
                }
                .fixedSize(horizontal: true, vertical: false)
                
                // Update Page Button
                Button {
                    showingProgressSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark")
                        Text("Update Page")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .font(.callout.weight(.medium))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(BookStrideTheme.cardLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .fixedSize(horizontal: true, vertical: false)
                
                // Open in Apple Books
                Button {
                    AppleBooksService.openAppleBooks()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages")
                        Text("Apple Books")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .font(.callout.weight(.medium))
                    .foregroundColor(BookStrideTheme.forestGreen)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(BookStrideTheme.cardLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .fixedSize(horizontal: true, vertical: false)
                
                // Add Note / Quote
                Button {
                    showingAddJournalSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                        Text("Add Note")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .font(.callout.weight(.medium))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(BookStrideTheme.cardLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
    
    private var progressAndInsightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(title: "Reading Progress")
            
            VStack(spacing: 16) {
                // Progress Bar
                VStack(spacing: 6) {
                    ProgressView(value: book.progressFraction)
                        .tint(BookStrideTheme.forestGreen)
                    
                    HStack {
                        Text(Formatters.formatPages(current: book.currentPage, total: book.totalPages))
                            .font(.subheadline)
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                        Spacer()
                        Text(Formatters.formatPercentage(book.progressFraction))
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(BookStrideTheme.forestGreen)
                    }
                }
                
                if let est = estimatedCompletionString {
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(BookStrideTheme.forestGreen)
                        Text("Estimated Completion: \(est)")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        Spacer()
                    }
                }
            }
            .padding(20)
            .BookStrideCardStyle()
        }
    }
    
    private var notesAndQuotesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(title: "Journal & Quotes") {
                Button {
                    showingAddJournalSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.callout.weight(.medium))
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
            
            if book.journalEntries.isEmpty {
                Text("No notes or quotes recorded for this book yet.")
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .BookStrideCardStyle()
            } else {
                VStack(spacing: 12) {
                    ForEach(book.journalEntries.sorted { $0.createdAt > $1.createdAt }) { entry in
                        JournalCardView(entry: entry, onDelete: {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        })
                    }
                }
            }
        }
    }
    
    private var sessionsHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(title: "Reading History (\(completedSessions.count))")
            
            if completedSessions.isEmpty {
                Text("No reading sessions logged yet.")
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .BookStrideCardStyle()
            } else {
                VStack(spacing: 10) {
                    ForEach(completedSessions) { session in
                        SessionRowView(session: session)
                    }
                }
            }
        }
    }
    
    private func markFinished() {
        book.status = .finished
        book.finishDate = Date()
        if let total = book.totalPages {
            book.currentPage = total
        }
        book.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func saveFinishedSession(endPage: Int?, notes: String?) {
        guard let snapshot = timerService.finishSession(endPage: endPage, notes: notes) else { return }
        
        let session = ReadingSession(
            id: snapshot.id,
            book: book,
            startedAt: snapshot.startedAt,
            endedAt: snapshot.endedAt,
            status: .completed,
            accumulatedActiveSeconds: snapshot.accumulatedActiveSeconds,
            lastResumedAt: nil,
            lastPausedAt: nil,
            pausedDurationSeconds: snapshot.pausedDurationSeconds,
            startPage: snapshot.startPage,
            endPage: snapshot.endPage,
            notes: snapshot.notes
        )
        modelContext.insert(session)
        
        if let end = snapshot.endPage, end > 0 {
            book.currentPage = end
            if let total = book.totalPages, end >= total {
                book.status = .finished
                book.finishDate = Date()
            }
            book.updatedAt = Date()
        }
        
        try? modelContext.save()
    }
}

