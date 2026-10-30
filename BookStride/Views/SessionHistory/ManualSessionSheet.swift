//
//  ManualSessionSheet.swift
//  BookStride
//
//  Sheet for logging past reading sessions or editing recorded ones with strict validation.
//

import SwiftUI
import SwiftData

public struct ManualSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Book.title) private var allBooks: [Book]
    
    public var sessionToEdit: ReadingSession?
    
    @State private var selectedBookId: UUID?
    @State private var date: Date = Date()
    @State private var durationMinutes: Int = 30
    @State private var startPageString: String = ""
    @State private var endPageString: String = ""
    @State private var notes: String = ""
    @State private var updateBookProgress: Bool = true
    
    // Validation
    @State private var errorMessage: String = ""
    @State private var showingError: Bool = false
    
    public init(sessionToEdit: ReadingSession? = nil) {
        self.sessionToEdit = sessionToEdit
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Book")) {
                    Picker("Select Book", selection: $selectedBookId) {
                        Text("None (Unassigned)").tag(UUID?.none)
                        ForEach(allBooks) { b in
                            Text(b.title).tag(UUID?.some(b.id))
                        }
                    }
                }
                
                Section(header: Text("Date & Duration")) {
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    
                    HStack {
                        Text("Reading Time")
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                        Spacer()
                        Text("\(durationMinutes) min")
                            .foregroundColor(BookStrideTheme.forestGreen)
                            .fontWeight(.semibold)
                        Stepper("", value: $durationMinutes, in: 1...600, step: 5)
                            .labelsHidden()
                    }
                }
                
                Section(header: Text("Pages (Optional)")) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start Page")
                                .font(.caption)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                            TextField("e.g. 50", text: $startPageString)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("End Page")
                                .font(.caption)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                            TextField("e.g. 75", text: $endPageString)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                    }
                    
                    if selectedBookId != nil {
                        Toggle("Update book's current page", isOn: $updateBookProgress)
                    }
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextField("Reflections or key takeaways", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(sessionToEdit == nil ? "Log Past Session" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
            .frame(minWidth: 500, idealWidth: 540, minHeight: 520, idealHeight: 620)
            .onAppear {
                loadInitialValues()
            }
            .alert("Invalid Input", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadInitialValues() {
        guard let s = sessionToEdit else {
            // Default to currently reading book if available
            if let firstCurrent = allBooks.first(where: { $0.status == .currentlyReading }) {
                selectedBookId = firstCurrent.id
                if let curr = firstCurrent.currentPage {
                    startPageString = "\(curr)"
                }
            }
            return
        }
        
        selectedBookId = s.book?.id
        date = s.startedAt
        durationMinutes = max(1, s.activeDurationSeconds / 60)
        if let st = s.startPage { startPageString = "\(st)" }
        if let en = s.endPage { endPageString = "\(en)" }
        notes = s.notes ?? ""
    }
    
    private func saveSession() {
        guard durationMinutes > 0 else {
            errorMessage = "Duration must be at least 1 minute."
            showingError = true
            return
        }
        
        let startPage = Int(startPageString.trimmingCharacters(in: .whitespacesAndNewlines))
        let endPage = Int(endPageString.trimmingCharacters(in: .whitespacesAndNewlines))
        
        if let s = startPage, s < 0 {
            errorMessage = "Start page cannot be negative."
            showingError = true
            return
        }
        
        if let e = endPage, e < 0 {
            errorMessage = "End page cannot be negative."
            showingError = true
            return
        }
        
        if let s = startPage, let e = endPage, e < s {
            errorMessage = "Ending page (\(e)) cannot be less than starting page (\(s))."
            showingError = true
            return
        }
        
        let chosenBook = allBooks.first(where: { $0.id == selectedBookId })
        let activeSeconds = durationMinutes * 60
        let endedAt = date.addingTimeInterval(Double(activeSeconds))
        
        if let existing = sessionToEdit {
            existing.book = chosenBook
            existing.startedAt = date
            existing.endedAt = endedAt
            existing.accumulatedActiveSeconds = activeSeconds
            existing.pausedDurationSeconds = 0
            existing.startPage = startPage
            existing.endPage = endPage
            existing.notes = notes.isEmpty ? nil : notes
            existing.updatedAt = Date()
        } else {
            let newSession = ReadingSession(
                book: chosenBook,
                startedAt: date,
                endedAt: endedAt,
                status: .completed,
                accumulatedActiveSeconds: activeSeconds,
                lastResumedAt: nil,
                lastPausedAt: nil,
                pausedDurationSeconds: 0,
                startPage: startPage,
                endPage: endPage,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(newSession)
        }
        
        if updateBookProgress, let book = chosenBook, let end = endPage, end > 0 {
            book.currentPage = end
            if let total = book.totalPages, end >= total {
                book.status = .finished
                if book.finishDate == nil {
                    book.finishDate = date
                }
            }
            book.updatedAt = Date()
        }
        
        try? modelContext.save()
        dismiss()
    }
}

