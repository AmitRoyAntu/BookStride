//
//  ActiveSessionView.swift
//  BookStride
//
//  Dedicated full-focus screen for an active reading session.
//

import SwiftUI
import SwiftData

public struct ActiveSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var timerService: ReadingTimerService
    
    public var associatedBook: Book?
    public var onFinish: (Int?, String?) -> Void
    
    @State private var showingFinishConfirmation: Bool = false
    @State private var showingCancelConfirmation: Bool = false
    @State private var endPageString: String = ""
    @State private var sessionNotes: String = ""
    @State private var showingPageValidationError: Bool = false
    @State private var pageValidationError: String = ""
    
    public init(
        timerService: ReadingTimerService,
        associatedBook: Book? = nil,
        onFinish: @escaping (Int?, String?) -> Void
    ) {
        self.timerService = timerService
        self.associatedBook = associatedBook
        self.onFinish = onFinish
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BookStrideTheme.warmIvory
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Book Header
                    if let book = associatedBook {
                        HStack(spacing: 16) {
                            BookCoverThumbnail(
                                imageData: book.coverImageData,
                                title: book.title,
                                author: book.author,
                                colorHex: book.coverColorHex,
                                iconName: book.coverIcon,
                                width: 70,
                                height: 105,
                                cornerRadius: 6
                            )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(book.title)
                                    .font(.system(.title3, design: .serif, weight: .bold))
                                    .foregroundColor(BookStrideTheme.deepCharcoal)
                                    .lineLimit(2)
                                
                                if !book.author.isEmpty {
                                    Text(book.author)
                                        .font(.subheadline)
                                        .foregroundColor(BookStrideTheme.mutedSlate)
                                }
                                
                                Text(Formatters.formatPages(current: book.currentPage, total: book.totalPages))
                                    .font(.caption)
                                    .foregroundColor(BookStrideTheme.forestGreen)
                            }
                            Spacer()
                        }
                        .padding(20)
                        .BookStrideCardStyle()
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                    
                    // Large Timer Display
                    VStack(spacing: 12) {
                        Text(Formatters.formatDuration(seconds: timerService.currentElapsedSeconds, style: .timer))
                            .font(.system(size: 72, weight: .light, design: .monospaced))
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(timerService.isPaused ? Color.orange : BookStrideTheme.forestGreen)
                                .frame(width: 8, height: 8)
                            
                            Text(timerService.isPaused ? "Session Paused" : "Actively Reading")
                                .font(.caption.weight(.medium))
                                .textCase(.uppercase)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(BookStrideTheme.cardLight)
                        )
                    }
                    
                    // Quick Action: Open Apple Books
                    Button {
                        AppleBooksService.openAppleBooks()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "book.pages")
                            Text("Open in Apple Books")
                        }
                        .font(.callout.weight(.medium))
                        .foregroundColor(BookStrideTheme.forestGreen)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(BookStrideTheme.forestGreen.opacity(0.4), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                    
                    // Primary Controls (Pause/Resume, Finish)
                    HStack(spacing: 24) {
                        // Pause / Resume Button
                        Button {
                            if timerService.isPaused {
                                timerService.resumeSession()
                            } else {
                                timerService.pauseSession()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: timerService.isPaused ? "play.fill" : "pause.fill")
                                Text(timerService.isPaused ? "Resume" : "Pause")
                            }
                            .font(.headline)
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(BookStrideTheme.cardLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                            )
                            .cornerRadius(14)
                        }
                        
                        // Finish Button
                        Button {
                            timerService.pauseSession()
                            if let curr = associatedBook?.currentPage {
                                endPageString = "\(curr)"
                            }
                            showingFinishConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Finish Session")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(BookStrideTheme.forestGreen)
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Reading Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) {
                        showingCancelConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Minimize") {
                        dismiss()
                    }
                    .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
            .confirmationDialog(
                "Discard Reading Session?",
                isPresented: $showingCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Session", role: .destructive) {
                    timerService.cancelSession()
                    dismiss()
                }
                Button("Keep Reading", role: .cancel) {}
            } message: {
                Text("This will cancel the active timer and will not save reading time.")
            }
            .sheet(isPresented: $showingFinishConfirmation) {
                NavigationStack {
                    Form {
                        Section(header: Text("Session Summary")) {
                            HStack {
                                Text("Time Read:")
                                Spacer()
                                Text(Formatters.formatDuration(seconds: timerService.currentElapsedSeconds, style: .full))
                                    .fontWeight(.semibold)
                                    .foregroundColor(BookStrideTheme.forestGreen)
                            }
                        }
                        
                        if associatedBook != nil {
                            Section(header: Text("Progress Update")) {
                                HStack {
                                    Text("Ending Page:")
                                    Spacer()
                                    TextField("Page number", text: $endPageString)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                        
                        Section(header: Text("Session Notes (Optional)")) {
                            TextField("Any thoughts, favorite lines, or takeaways?", text: $sessionNotes, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                    .navigationTitle("Finish Reading")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                showingFinishConfirmation = false
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                if let end = Int(endPageString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                    if let start = timerService.activeState?.startPage, end < start {
                                        pageValidationError = "Ending page (\(end)) cannot be less than starting page (\(start))."
                                        showingPageValidationError = true
                                        return
                                    }
                                    if let total = associatedBook?.totalPages, end > total {
                                        pageValidationError = "Ending page (\(end)) cannot exceed total book pages (\(total))."
                                        showingPageValidationError = true
                                        return
                                    }
                                }
                                
                                showingFinishConfirmation = false
                                let page = Int(endPageString.trimmingCharacters(in: .whitespacesAndNewlines))
                                onFinish(page, sessionNotes.isEmpty ? nil : sessionNotes)
                                dismiss()
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(BookStrideTheme.forestGreen)
                        }
                    }
                    .alert("Page Validation", isPresented: $showingPageValidationError) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(pageValidationError)
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

