//
//  ScanQuoteSheet.swift
//  BookStride
//
//  Camera and Photo-based quote scanner modal with on-device Vision OCR extraction,
//  review editor, page detection, and direct journal saving.
//

import SwiftUI
import SwiftData
import PhotosUI

public struct ScanQuoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Book.title) private var allBooks: [Book]
    
    public var preselectedBook: Book?
    public var onQuoteSaved: ((JournalEntry) -> Void)?
    public var onTextRecognized: ((String, Int?) -> Void)?
    
    @State private var selectedBookId: UUID?
    @State private var extractedText: String = ""
    @State private var pageNumberString: String = ""
    @State private var isFavorite: Bool = false
    
    // Scanning state
    @State private var isScanning: Bool = false
    @State private var errorMessage: String?
    @State private var showingCamera: Bool = false
    @State private var showingQuoteCardSheet: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var scannedImage: UIImage?
    
    public init(
        preselectedBook: Book? = nil,
        onQuoteSaved: ((JournalEntry) -> Void)? = nil,
        onTextRecognized: ((String, Int?) -> Void)? = nil
    ) {
        self.preselectedBook = preselectedBook
        self.onQuoteSaved = onQuoteSaved
        self.onTextRecognized = onTextRecognized
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isScanning {
                    scanningLoadingView
                } else if extractedText.isEmpty && scannedImage == nil {
                    capturePromptView
                } else {
                    reviewAndEditView
                }
            }
            .BookStrideBackground()
            .navigationTitle("Scan Book Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(onTextRecognized != nil ? "Use Text" : "Save Quote") {
                            saveQuote()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(BookStrideTheme.forestGreen)
                    }
                }
            }
            .onAppear {
                if let book = preselectedBook {
                    selectedBookId = book.id
                    if let curr = book.currentPage, curr > 0 {
                        pageNumberString = "\(curr)"
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                DocumentCameraScannerView { scannedImage in
                    processImage(scannedImage)
                } onCancel: {
                    // Do nothing on cancel
                }
            }
            .sheet(isPresented: $showingQuoteCardSheet) {
                QuoteCardSheet(
                    quote: extractedText,
                    bookTitle: allBooks.first(where: { $0.id == selectedBookId })?.title,
                    author: allBooks.first(where: { $0.id == selectedBookId })?.author,
                    pageNumber: Int(pageNumberString.trimmingCharacters(in: .whitespacesAndNewlines))
                )
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            processImage(image)
                        }
                    }
                }
            }
            .alert("Scan Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred while recognizing text.")
            }
        }
        .frame(minWidth: 540, idealWidth: 620, minHeight: 600, idealHeight: 700)
    }
    
    // MARK: - Capture Prompt (Empty State)
    
    private var capturePromptView: some View {
        VStack(spacing: 28) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(BookStrideTheme.forestGreen.opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 46))
                    .foregroundColor(BookStrideTheme.forestGreen)
            }
            
            VStack(spacing: 8) {
                Text("Scan Physical Book Passage")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                
                Text("Capture quotes directly from printed physical pages.\nRuns completely on-device without any cloud sync.")
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 32)
            
            VStack(spacing: 12) {
                if DocumentCameraScannerView.isSupported {
                    Button {
                        showingCamera = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Scan Page with Camera")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: 320)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(BookStrideTheme.forestGreen)
                        .cornerRadius(12)
                    }
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Photos")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: 320)
                    .padding(.vertical, 13)
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .background(BookStrideTheme.cardLight)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                    )
                }
            }
            .padding(.top, 8)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.caption)
                    .foregroundColor(BookStrideTheme.forestGreen)
                Text("100% offline text recognition powered by Apple Vision.")
                    .font(.caption)
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
            .padding(.bottom, 20)
        }
        .padding()
    }
    
    // MARK: - Scanning Indicator
    
    private var scanningLoadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
                .tint(BookStrideTheme.forestGreen)
            
            VStack(spacing: 6) {
                Text("Recognizing Text...")
                    .font(.headline)
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                Text("Extracting passage from page...")
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
            Spacer()
        }
    }
    
    // MARK: - Review and Edit View
    
    private var reviewAndEditView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with badge and rescan button
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "text.quote")
                            .font(.caption2.weight(.bold))
                        Text("Recognized Passage")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundColor(BookStrideTheme.forestGreen)
                    .background(BookStrideTheme.forestGreen.opacity(0.12))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Button {
                        scannedImage = nil
                        extractedText = ""
                        selectedPhotoItem = nil
                    } label: {
                        Label("Rescan", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.medium))
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                }
                
                // Extracted Quote Text Box
                VStack(alignment: .leading, spacing: 8) {
                    Text("Captured Quote")
                        .font(.caption.weight(.bold))
                        .foregroundColor(BookStrideTheme.mutedSlate)
                        .textCase(.uppercase)
                    
                    TextEditor(text: $extractedText)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(5)
                        .frame(minHeight: 180)
                        .padding(10)
                        .background(BookStrideTheme.cardLight)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                        )
                    
                    Text("Tip: You can edit or trim unwanted text directly above.")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                // Book and Page Metadata
                VStack(alignment: .leading, spacing: 14) {
                    Text("Book Details")
                        .font(.caption.weight(.bold))
                        .foregroundColor(BookStrideTheme.mutedSlate)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 0) {
                        // Book Picker
                        HStack {
                            Text("Book")
                                .font(.subheadline)
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                            Spacer()
                            Picker("", selection: $selectedBookId) {
                                Text("None (General Quote)").tag(UUID?.none)
                                ForEach(allBooks) { b in
                                    Text(b.title).tag(UUID?.some(b.id))
                                }
                            }
                            .tint(BookStrideTheme.forestGreen)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        
                        Divider()
                            .padding(.leading, 16)
                        
                        // Page Number
                        HStack {
                            Text("Page Number")
                                .font(.subheadline)
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                            Spacer()
                            TextField("Optional", text: $pageNumberString)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.plain)
                                .frame(width: 120)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                    .background(BookStrideTheme.cardLight)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                    )
                }
                
                // Favorite Toggle
                Toggle(isOn: $isFavorite) {
                    Label("Add to Favorites", systemImage: isFavorite ? "star.fill" : "star")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isFavorite ? BookStrideTheme.streakAmber : BookStrideTheme.deepCharcoal)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(BookStrideTheme.cardLight)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                )
                
                // Quote Card Preview Button
                Button {
                    showingQuoteCardSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles.rectangle.stack")
                        Text("Create Aesthetic Quote Card")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.forestGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BookStrideTheme.forestGreen.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BookStrideTheme.forestGreen.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }
    
    // MARK: - Processing & Saving
    
    private func processImage(_ image: UIImage) {
        scannedImage = image
        isScanning = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await QuoteScannerService.shared.recognizeText(from: image)
                await MainActor.run {
                    self.extractedText = result.fullText
                    if let page = result.detectedPageNumber, self.pageNumberString.isEmpty {
                        self.pageNumberString = "\(page)"
                    }
                    self.isScanning = false
                    
                    if result.fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.errorMessage = "No text could be recognized in the image. Please try holding the camera closer or in better lighting."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isScanning = false
                    self.errorMessage = "Failed to recognize text: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveQuote() {
        let trimmed = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let pageNum = Int(pageNumberString.trimmingCharacters(in: .whitespacesAndNewlines))
        
        if let onTextRecognized = onTextRecognized {
            onTextRecognized(trimmed, pageNum)
            dismiss()
            return
        }
        
        let targetBook = allBooks.first(where: { $0.id == selectedBookId })
        
        let newEntry = JournalEntry(
            book: targetBook,
            content: trimmed,
            entryType: .quote,
            pageNumber: pageNum,
            isFavorite: isFavorite
        )
        
        modelContext.insert(newEntry)
        try? modelContext.save()
        
        onQuoteSaved?(newEntry)
        dismiss()
    }
}
