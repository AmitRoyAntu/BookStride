//
//  BookPickerSheet.swift
//  BookStride
//
//  Book selection sheet before starting a live reading session.
//

import SwiftUI
import SwiftData

public struct BookPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    
    public var onSelectBook: (Book?, Int?) -> Void
    public var onAddNewBook: () -> Void
    
    @State private var selectedBook: Book?
    @State private var startPageString: String = ""
    
    public init(
        onSelectBook: @escaping (Book?, Int?) -> Void,
        onAddNewBook: @escaping () -> Void
    ) {
        self.onSelectBook = onSelectBook
        self.onAddNewBook = onAddNewBook
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if books.isEmpty {
                    VStack(spacing: 20) {
                        EmptyStateCard(
                            iconName: "books.vertical",
                            title: "Your Library is Empty",
                            message: "Add your first book to begin tracking reading sessions.",
                            buttonTitle: "Add a Book",
                            action: {
                                dismiss()
                                onAddNewBook()
                            }
                        )
                        
                        Button {
                            onSelectBook(nil, nil)
                            dismiss()
                        } label: {
                            Text("Track session without book")
                                .font(.callout)
                                .foregroundColor(BookStrideTheme.forestGreen)
                        }
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Button {
                                onSelectBook(nil, nil)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "timer")
                                        .font(.title2)
                                        .foregroundColor(BookStrideTheme.forestGreen)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Open Reading Session")
                                            .font(.body.weight(.medium))
                                            .foregroundColor(BookStrideTheme.deepCharcoal)
                                        Text("Track reading without linking to a specific book")
                                            .font(.caption)
                                            .foregroundColor(BookStrideTheme.mutedSlate)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Section(header: Text("Choose from Library")) {
                            ForEach(books) { book in
                                Button {
                                    selectedBook = book
                                    if let curr = book.currentPage {
                                        startPageString = "\(curr)"
                                    }
                                } label: {
                                    HStack(spacing: 16) {
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
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(book.title)
                                                .font(.headline)
                                                .foregroundColor(BookStrideTheme.deepCharcoal)
                                            
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
                                        
                                        if selectedBook?.id == book.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(BookStrideTheme.forestGreen)
                                                .font(.title3)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if let selected = selectedBook {
                            Section(header: Text("Starting Page for \"\(selected.title)\"")) {
                                HStack {
                                    Text("Current page:")
                                        .foregroundColor(BookStrideTheme.deepCharcoal)
                                    Spacer()
                                    TextField("Page number", text: $startPageString)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 110)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Select Book to Read")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if selectedBook != nil {
                        Button("Start") {
                            let page = Int(startPageString.trimmingCharacters(in: .whitespacesAndNewlines))
                            onSelectBook(selectedBook, page)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(BookStrideTheme.forestGreen)
                    }
                }
            }
            .frame(minWidth: 480, idealWidth: 540, minHeight: 460, idealHeight: 580)
        }
    }
}

