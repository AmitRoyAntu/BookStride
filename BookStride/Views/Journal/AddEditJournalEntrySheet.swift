//
//  AddEditJournalEntrySheet.swift
//  BookStride
//
//  Sheet to add or edit journal notes, quotes, and reflections with unsaved changes warnings.
//

import SwiftUI
import SwiftData

public struct AddEditJournalEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Book.title) private var allBooks: [Book]
    
    public var entryToEdit: JournalEntry?
    public var associatedBook: Book?
    public var defaultEntryType: JournalEntryType
    
    @State private var selectedBookId: UUID?
    @State private var entryType: JournalEntryType
    @State private var content: String = ""
    @State private var pageNumberString: String = ""
    @State private var isFavorite: Bool = false
    
    // Initial state snapshot for dirty checking
    @State private var initialContent: String = ""
    @State private var initialPageNumberString: String = ""
    @State private var initialSelectedBookId: UUID?
    @State private var initialEntryType: JournalEntryType = .note
    @State private var initialIsFavorite: Bool = false
    
    // Alerts
    @State private var showingEmptyContentError: Bool = false
    @State private var showingPageNumberError: Bool = false
    @State private var showingDiscardConfirmation: Bool = false
    
    public init(
        entryToEdit: JournalEntry? = nil,
        associatedBook: Book? = nil,
        defaultEntryType: JournalEntryType = .note
    ) {
        self.entryToEdit = entryToEdit
        self.associatedBook = associatedBook
        self.defaultEntryType = defaultEntryType
        _entryType = State(initialValue: entryToEdit?.entryType ?? defaultEntryType)
    }
    
    private var hasUnsavedChanges: Bool {
        content != initialContent ||
        pageNumberString != initialPageNumberString ||
        selectedBookId != initialSelectedBookId ||
        entryType != initialEntryType ||
        isFavorite != initialIsFavorite
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Entry Type
                Section(header: Text("Entry Type")) {
                    Picker("Type", selection: $entryType) {
                        ForEach(JournalEntryType.allCases) { t in
                            Label(t.rawValue, systemImage: t.iconName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Section 2: Associated Book & Page
                Section(header: Text("Book Context")) {
                    Picker("Book", selection: $selectedBookId) {
                        Text("None (General Reading Entry)").tag(UUID?.none)
                        ForEach(allBooks) { b in
                            Text(b.title).tag(UUID?.some(b.id))
                        }
                    }
                    
                    HStack {
                        Text("Page Number:")
                        Spacer()
                        TextField("Optional (e.g. 142)", text: $pageNumberString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Section 3: Content
                Section(header: Text(contentSectionHeader)) {
                    TextField(
                        placeholderPrompt,
                        text: $content,
                        axis: .vertical
                    )
                    .lineLimit(6...14)
                }
                
                // Section 4: Favorite Option
                Section {
                    Toggle("Mark as Favorite", isOn: $isFavorite)
                }
            }
            .navigationTitle(entryToEdit == nil ? "New \(entryType.rawValue)" : "Edit \(entryType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        handleCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
            .onAppear {
                loadInitialValues()
            }
            .alert("Empty Content", isPresented: $showingEmptyContentError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please write some content for your \(entryType.rawValue.lowercased()) before saving.")
            }
            .alert("Invalid Page Number", isPresented: $showingPageNumberError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Page number must be a positive number.")
            }
            .confirmationDialog(
                "Discard Unsaved Changes?",
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes in this journal entry. Are you sure you want to discard them?")
            }
        }
    }
    
    // MARK: - Helpers
    
    private var contentSectionHeader: String {
        switch entryType {
        case .quote: return "Quote / Highlighted Passage"
        case .reflection: return "Personal Reflection"
        case .note: return "Reading Note"
        case .keyTakeaway: return "Key Takeaway"
        }
    }
    
    private var placeholderPrompt: String {
        switch entryType {
        case .quote: return "Type or paste the memorable quote..."
        case .reflection: return "Reflect on insights, connections, or lessons from this reading..."
        case .note: return "Jot down summary notes, thoughts, or ideas..."
        case .keyTakeaway: return "Capture core lessons, takeaways, or concepts..."
        }
    }
    
    private func loadInitialValues() {
        if let entry = entryToEdit {
            selectedBookId = entry.book?.id
            entryType = entry.entryType
            content = entry.content
            if let p = entry.pageNumber { pageNumberString = "\(p)" }
            isFavorite = entry.isFavorite
        } else if let book = associatedBook {
            selectedBookId = book.id
            entryType = defaultEntryType
            if let curr = book.currentPage, curr > 0 {
                pageNumberString = "\(curr)"
            }
        } else {
            entryType = defaultEntryType
        }
        
        // Save snapshots for dirty comparison
        initialContent = content
        initialPageNumberString = pageNumberString
        initialSelectedBookId = selectedBookId
        initialEntryType = entryType
        initialIsFavorite = isFavorite
    }
    
    private func handleCancel() {
        if hasUnsavedChanges {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }
    
    private func saveEntry() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showingEmptyContentError = true
            return
        }
        
        var pageNum: Int? = nil
        let trimmedPage = pageNumberString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPage.isEmpty {
            guard let parsed = Int(trimmedPage), parsed >= 0 else {
                showingPageNumberError = true
                return
            }
            pageNum = parsed
        }
        
        let chosenBook = allBooks.first(where: { $0.id == selectedBookId })
        
        if let existing = entryToEdit {
            existing.book = chosenBook
            existing.entryType = entryType
            existing.content = trimmed
            existing.pageNumber = pageNum
            existing.isFavorite = isFavorite
            existing.updatedAt = Date()
        } else {
            let newEntry = JournalEntry(
                book: chosenBook,
                content: trimmed,
                entryType: entryType,
                pageNumber: pageNum,
                isFavorite: isFavorite
            )
            modelContext.insert(newEntry)
        }
        
        try? modelContext.save()
        dismiss()
    }
}
