//
//  AddEditJournalEntrySheet.swift
//  BookStride
//
//  Sheet to add or edit journal notes and favorite quotes.
//

import SwiftUI
import SwiftData

public struct AddEditJournalEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Book.title) private var allBooks: [Book]
    
    public var entryToEdit: JournalEntry?
    public var associatedBook: Book?
    
    @State private var selectedBookId: UUID?
    @State private var entryType: JournalEntryType = .note
    @State private var content: String = ""
    @State private var pageNumberString: String = ""
    @State private var isFavorite: Bool = false
    @State private var showingError: Bool = false
    
    public init(entryToEdit: JournalEntry? = nil, associatedBook: Book? = nil) {
        self.entryToEdit = entryToEdit
        self.associatedBook = associatedBook
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Entry Type")) {
                    Picker("Type", selection: $entryType) {
                        ForEach(JournalEntryType.allCases) { t in
                            Label(t.rawValue, systemImage: t.iconName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Associated Book")) {
                    Picker("Book", selection: $selectedBookId) {
                        Text("None (General Reading Note)").tag(UUID?.none)
                        ForEach(allBooks) { b in
                            Text(b.title).tag(UUID?.some(b.id))
                        }
                    }
                    
                    HStack {
                        Text("Page Number:")
                        Spacer()
                        TextField("Optional", text: $pageNumberString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text(entryType == .quote ? "Quote Passage" : "Note Content")) {
                    TextField(
                        entryType == .quote ? "Enter quote or highlighted passage..." : "Write your thoughts or reflection...",
                        text: $content,
                        axis: .vertical
                    )
                    .lineLimit(5...10)
                }
                
                Section {
                    Toggle("Mark as Favorite", isOn: $isFavorite)
                }
            }
            .navigationTitle(entryToEdit == nil ? "New Journal Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
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
            .alert("Empty Entry", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please write some content for your note or quote before saving.")
            }
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
            if let curr = book.currentPage {
                pageNumberString = "\(curr)"
            }
        }
    }
    
    private func saveEntry() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showingError = true
            return
        }
        
        let page = Int(pageNumberString.trimmingCharacters(in: .whitespacesAndNewlines))
        let chosenBook = allBooks.first(where: { $0.id == selectedBookId })
        
        if let existing = entryToEdit {
            existing.book = chosenBook
            existing.entryType = entryType
            existing.content = trimmed
            existing.pageNumber = page
            existing.isFavorite = isFavorite
            existing.updatedAt = Date()
        } else {
            let newEntry = JournalEntry(
                book: chosenBook,
                content: trimmed,
                entryType: entryType,
                pageNumber: page,
                isFavorite: isFavorite
            )
            modelContext.insert(newEntry)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

