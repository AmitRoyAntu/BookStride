//
//  AddEditBookSheet.swift
//  BookStride
//
//  Form to add or edit a book with page validation and aesthetic customization.
//

import SwiftUI
import SwiftData
import PhotosUI

public struct AddEditBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    public var bookToEdit: Book?
    
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var totalPagesString: String = ""
    @State private var currentPageString: String = ""
    @State private var status: ReadingStatus = .currentlyReading
    @State private var coverColorHex: String = "forest"
    @State private var coverIcon: String = "book.closed"
    @State private var rating: Int = 0
    @State private var bookDescription: String = ""
    @State private var appleBooksLink: String = ""
    @State private var startDate: Date = Date()
    @State private var finishDate: Date = Date()
    @State private var hasStartDate: Bool = true
    @State private var hasFinishDate: Bool = false
    
    // Photo Picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var coverImageData: Data?
    
    // Validation alert
    @State private var validationErrorMessage: String?
    @State private var showingValidationError: Bool = false
    
    private let availableColors = ["forest", "terracotta", "navy", "slate", "burgundy", "sage", "gold", "plum"]
    private let availableIcons = ["book.closed", "bookmark", "feather", "sun.max", "crown", "sparkles", "mountain.2", "bolt.fill"]
    
    public init(bookToEdit: Book? = nil) {
        self.bookToEdit = bookToEdit
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // Section: Book Cover & Preview
                Section(header: Text("Book Appearance")) {
                    HStack(alignment: .top, spacing: 20) {
                        BookCoverThumbnail(
                            imageData: coverImageData,
                            title: title.isEmpty ? "Book Title" : title,
                            author: author,
                            colorHex: coverColorHex,
                            iconName: coverIcon,
                            width: 80,
                            height: 120,
                            cornerRadius: 6
                        )
                        
                        VStack(alignment: .leading, spacing: 14) {
                            // Cover Color Choices
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Cover Palette")
                                    .font(.caption)
                                    .foregroundColor(BookStrideTheme.mutedSlate)
                                
                                HStack(spacing: 8) {
                                    ForEach(availableColors, id: \.self) { colorKey in
                                        Circle()
                                            .fill(BookStrideTheme.bookCoverColors[colorKey] ?? .gray)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: coverColorHex == colorKey ? 2 : 0)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(BookStrideTheme.deepCharcoal, lineWidth: coverColorHex == colorKey ? 1.5 : 0)
                                            )
                                            .onTapGesture {
                                                coverColorHex = colorKey
                                            }
                                    }
                                }
                            }
                            
                            // Photo picker
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label(coverImageData == nil ? "Choose Custom Cover Image" : "Replace Cover Image", systemImage: "photo")
                                    .font(.caption)
                                    .foregroundColor(BookStrideTheme.forestGreen)
                            }
                            
                            if coverImageData != nil {
                                Button("Remove Custom Image", role: .destructive) {
                                    coverImageData = nil
                                    selectedPhotoItem = nil
                                }
                                .font(.caption2)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Section: Basic Info
                Section(header: Text("Book Details")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title (Required)")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        TextField("Book Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Author")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        TextField("Author name", text: $author)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Picker("Reading Status", selection: $status) {
                        ForEach(ReadingStatus.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }
                
                // Section: Page Progress & Validation
                Section(header: Text("Pages & Progress")) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Page")
                                .font(.caption)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                            TextField("0", text: $currentPageString)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Pages")
                                .font(.caption)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                            TextField("Optional", text: $totalPagesString)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                    }
                }
                
                // Section: Dates & Rating
                Section(header: Text("Reading Journal Info")) {
                    Toggle("Started Date", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("Date Started", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    
                    Toggle("Finished Date", isOn: $hasFinishDate)
                    if hasFinishDate {
                        DatePicker("Date Finished", selection: $finishDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    
                    // Star Rating
                    HStack {
                        Text("Personal Rating:")
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundColor(star <= rating ? BookStrideTheme.streakAmber : BookStrideTheme.mutedSlate)
                                    .onTapGesture {
                                        if rating == star {
                                            rating = 0
                                        } else {
                                            rating = star
                                        }
                                    }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description or Thoughts")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        TextField("Optional summary, thoughts, or notes", text: $bookDescription, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                // Section: Apple Books Link
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("https://books.apple.com/... or ibooks://", text: $appleBooksLink)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        
                        Text("Store link (https://books.apple.com/...) or scheme (ibooks://...) to launch directly from BookStride.")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Apple Books Link (Optional)")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(bookToEdit == nil ? "Add Book" : "Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBook()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
            .frame(minWidth: 520, idealWidth: 560, minHeight: 580, idealHeight: 680)
            .onAppear {
                loadInitialData()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        coverImageData = data
                    }
                }
            }
            .alert("Validation Error", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationErrorMessage ?? "Please check your inputs.")
            }
        }
    }
    
    private func loadInitialData() {
        guard let book = bookToEdit else { return }
        title = book.title
        author = book.author
        if let total = book.totalPages { totalPagesString = "\(total)" }
        if let current = book.currentPage { currentPageString = "\(current)" }
        status = book.status
        coverColorHex = book.coverColorHex
        coverIcon = book.coverIcon
        coverImageData = book.coverImageData
        rating = book.rating ?? 0
        bookDescription = book.bookDescription ?? ""
        appleBooksLink = book.appleBooksURL ?? ""
        
        if let start = book.startDate {
            startDate = start
            hasStartDate = true
        } else {
            hasStartDate = false
        }
        
        if let finish = book.finishDate {
            finishDate = finish
            hasFinishDate = true
        } else {
            hasFinishDate = (book.status == .finished)
        }
    }
    
    private func saveBook() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            validationErrorMessage = "Book title cannot be blank."
            showingValidationError = true
            return
        }
        
        let total = Int(totalPagesString.trimmingCharacters(in: .whitespacesAndNewlines))
        let current = Int(currentPageString.trimmingCharacters(in: .whitespacesAndNewlines))
        
        if let tot = total, tot < 1 {
            validationErrorMessage = "Total pages must be greater than zero."
            showingValidationError = true
            return
        }
        
        if let cur = current, cur < 0 {
            validationErrorMessage = "Current page cannot be negative."
            showingValidationError = true
            return
        }
        
        // Requirement: Current page must not exceed total pages when total pages is known
        if let tot = total, let cur = current, cur > tot {
            validationErrorMessage = "Current page (\(cur)) cannot exceed total pages (\(tot))."
            showingValidationError = true
            return
        }
        
        let sDate = hasStartDate ? startDate : nil
        let fDate = hasFinishDate ? finishDate : (status == .finished ? Date() : nil)
        let cleanLink = appleBooksLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLink = cleanLink.isEmpty ? nil : cleanLink
        
        if let existing = bookToEdit {
            existing.title = trimmedTitle
            existing.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.totalPages = total
            existing.currentPage = current
            existing.status = status
            existing.coverColorHex = coverColorHex
            existing.coverIcon = coverIcon
            existing.coverImageData = coverImageData
            existing.rating = rating > 0 ? rating : nil
            existing.bookDescription = bookDescription.isEmpty ? nil : bookDescription
            existing.appleBooksURL = finalLink
            existing.startDate = sDate
            existing.finishDate = fDate
            existing.updatedAt = Date()
        } else {
            let newBook = Book(
                title: trimmedTitle,
                author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                coverImageData: coverImageData,
                coverColorHex: coverColorHex,
                coverIcon: coverIcon,
                totalPages: total,
                currentPage: current,
                status: status,
                startDate: sDate,
                finishDate: fDate,
                rating: rating > 0 ? rating : nil,
                bookDescription: bookDescription.isEmpty ? nil : bookDescription,
                appleBooksURL: finalLink
            )
            modelContext.insert(newBook)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

