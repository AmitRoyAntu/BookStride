//
//  UpdateProgressSheet.swift
//  BookStride
//
//  Quick sheet to update current page progress for a book.
//

import SwiftUI
import SwiftData

public struct UpdateProgressSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var book: Book
    @State private var pageString: String = ""
    @State private var markAsFinished: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    public init(book: Book) {
        self.book = book
        _pageString = State(initialValue: "\(book.currentPage ?? 0)")
        _markAsFinished = State(initialValue: book.status == .finished)
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Book Progress")) {
                    HStack {
                        Text("Current Page:")
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                        Spacer()
                        TextField("Page", text: $pageString)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    
                    if let total = book.totalPages {
                        HStack {
                            Text("Total Pages:")
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                            Spacer()
                            Text("\(total)")
                                .foregroundColor(BookStrideTheme.mutedSlate)
                        }
                    }
                    
                    Toggle("Mark as Finished", isOn: $markAsFinished)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProgress()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
            .frame(minWidth: 440, idealWidth: 480, minHeight: 240, idealHeight: 280)
            .alert("Invalid Page", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.medium])
    }
    
    private func saveProgress() {
        guard let page = Int(pageString.trimmingCharacters(in: .whitespacesAndNewlines)), page >= 0 else {
            errorMessage = "Please enter a valid page number."
            showingError = true
            return
        }
        
        if let total = book.totalPages, page > total {
            errorMessage = "Current page cannot exceed total pages (\(total))."
            showingError = true
            return
        }
        
        book.currentPage = page
        if markAsFinished || (book.totalPages != nil && page >= book.totalPages!) {
            book.status = .finished
            if book.finishDate == nil {
                book.finishDate = Date()
            }
        } else if book.status == .wantToRead && page > 0 {
            book.status = .currentlyReading
            if book.startDate == nil {
                book.startDate = Date()
            }
        }
        
        book.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}

