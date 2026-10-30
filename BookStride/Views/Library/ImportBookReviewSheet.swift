//
//  ImportBookReviewSheet.swift
//  BookStride
//
//  Review and metadata editing sheet presented when importing EPUB or PDF documents.
//  Includes duplicate book warnings, cover preview, and Apple Books link options.
//

import SwiftUI
import SwiftData

public struct ImportBookReviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var existingBooks: [Book]
    
    public var metadata: ExtractedBookMetadata
    public var onImportSuccess: ((Book) -> Void)?
    
    @State private var title: String
    @State private var author: String
    @State private var totalPagesString: String
    @State private var selectedStatus: ReadingStatus = .currentlyReading
    @State private var selectedColor: String = "forest"
    @State private var appleBooksLink: String = ""
    @State private var bookDescription: String = ""
    @State private var showingDuplicateOverrideConfirmation: Bool = false
    
    private let availableColors = ["forest", "terracotta", "navy", "slate", "burgundy", "sage", "gold", "plum"]
    
    public init(
        metadata: ExtractedBookMetadata,
        onImportSuccess: ((Book) -> Void)? = nil
    ) {
        self.metadata = metadata
        self.onImportSuccess = onImportSuccess
        
        _title = State(initialValue: metadata.title)
        _author = State(initialValue: metadata.author)
        _totalPagesString = State(initialValue: metadata.totalPages != nil ? "\(metadata.totalPages!)" : "")
        _appleBooksLink = State(initialValue: metadata.appleBooksURL ?? "")
        _bookDescription = State(initialValue: metadata.bookDescription ?? "")
    }
    
    private var detectedDuplicate: Book? {
        BookImportService.findDuplicate(title: title, author: author, in: existingBooks, titleOf: { $0.title }, authorOf: { $0.author })
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Document & Cover Header
                Section {
                    HStack(alignment: .top, spacing: 20) {
                        BookCoverThumbnail(
                            imageData: metadata.coverImageData,
                            title: title.isEmpty ? "Untitled" : title,
                            author: author,
                            colorHex: selectedColor,
                            iconName: metadata.format.iconName,
                            width: 90,
                            height: 135,
                            cornerRadius: 8
                        )
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Label(metadata.format.rawValue, systemImage: metadata.format.iconName)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(BookStrideTheme.forestGreen)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(BookStrideTheme.forestGreen.opacity(0.12))
                                    .cornerRadius(6)
                                
                                if metadata.isDRMProtected {
                                    Label("DRM Protected", systemImage: "lock.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(BookStrideTheme.streakAmber)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(BookStrideTheme.streakAmber.opacity(0.12))
                                        .cornerRadius(6)
                                }
                            }
                            
                            Text(metadata.fileName)
                                .font(.caption)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                                .lineLimit(2)
                            
                            Text("Extracted locally. BookStride does not duplicate large files into system storage.")
                                .font(.caption2)
                                .foregroundColor(BookStrideTheme.mutedSlate)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                // Section 2: Duplicate Warning Banner
                if let duplicate = detectedDuplicate {
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundColor(BookStrideTheme.streakAmber)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Possible Duplicate Detected")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(BookStrideTheme.deepCharcoal)
                                Text("A book titled \"\(duplicate.title)\" \(duplicate.author.isEmpty ? "" : "by \(duplicate.author)") already exists in your library.")
                                    .font(.caption)
                                    .foregroundColor(BookStrideTheme.mutedSlate)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Section 3: Book Details
                Section(header: Text("Book Information")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        TextField("Book Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Author")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        TextField("Author", text: $author)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Pages")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        TextField("Total Pages", text: $totalPagesString)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                    }
                    
                    Picker("Reading Status", selection: $selectedStatus) {
                        ForEach(ReadingStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
                
                // Section 4: Apple Books Integration Link
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("https://books.apple.com/... or ibooks://", text: $appleBooksLink)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                        
                        Text("Add a books.apple.com or ibooks:// link to open this book directly in Apple Books from the book detail screen.")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Apple Books Integration (Optional)")
                }
                
                // Section 5: Cover Palette Preset
                if metadata.coverImageData == nil {
                    Section(header: Text("Cover Color Theme")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableColors, id: \.self) { color in
                                    Circle()
                                        .fill(BookStrideTheme.bookCoverColors[color] ?? Color.gray)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? BookStrideTheme.deepCharcoal : Color.clear, lineWidth: 3)
                                        )
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Import Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save to Library") {
                        handleSave()
                    }
                    .font(.headline)
                    .foregroundColor(BookStrideTheme.forestGreen)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(minWidth: 520, idealWidth: 560, minHeight: 560, idealHeight: 680)
            .alert("Import Duplicate Book?", isPresented: $showingDuplicateOverrideConfirmation) {
                Button("Import Anyway") {
                    persistBook()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A book with this title is already in your library. Would you like to create another entry?")
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleSave() {
        if detectedDuplicate != nil {
            showingDuplicateOverrideConfirmation = true
        } else {
            persistBook()
        }
    }
    
    private func persistBook() {
        let pages = Int(totalPagesString.trimmingCharacters(in: .whitespacesAndNewlines))
        let cleanLink = appleBooksLink.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newBook = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            coverImageData: metadata.coverImageData,
            coverColorHex: selectedColor,
            coverIcon: metadata.format.iconName,
            totalPages: pages,
            currentPage: selectedStatus == .finished ? pages : 0,
            status: selectedStatus,
            startDate: selectedStatus == .currentlyReading ? Date() : nil,
            finishDate: selectedStatus == .finished ? Date() : nil,
            bookDescription: bookDescription.isEmpty ? nil : bookDescription,
            appleBooksURL: cleanLink.isEmpty ? nil : cleanLink,
            importedFileName: metadata.fileName,
            sourceFormat: metadata.format
        )
        
        modelContext.insert(newBook)
        try? modelContext.save()
        
        onImportSuccess?(newBook)
        dismiss()
    }
}
