//
//  QuoteCardSheet.swift
//  BookStride
//
//  Interactive customization and export sheet for rendering quotes into
//  aesthetic, high-typography image cards for Photos and social sharing.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct QuoteCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public let quote: String
    public let bookTitle: String?
    public let author: String?
    public let pageNumber: Int?
    
    @State private var config = QuoteCardConfig()
    
    // Export & Sharing state
    @State private var isExporting: Bool = false
    @State private var showingShareSheet: Bool = false
    @State private var shareImageURL: URL? = nil
    @State private var showingSuccessToast: Bool = false
    @State private var successToastMessage: String = ""
    @State private var showingErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    public init(
        quote: String,
        bookTitle: String? = nil,
        author: String? = nil,
        pageNumber: Int? = nil
    ) {
        self.quote = quote
        self.bookTitle = bookTitle
        self.author = author
        self.pageNumber = pageNumber
    }
    
    public init(entry: JournalEntry) {
        self.quote = entry.content
        self.bookTitle = entry.book?.title
        self.author = entry.book?.author
        self.pageNumber = entry.pageNumber
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Live Card Preview Canvas
                cardPreviewCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 245/255, green: 243/255, blue: 239/255).opacity(0.6))
                
                Divider()
                
                // Bottom Customization Controls
                customizationControls
                    .frame(maxHeight: 280)
                    .background(BookStrideTheme.cardLight)
            }
            .navigationTitle("Aesthetic Quote Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        // Copy image to clipboard
                        Button {
                            copyImageToClipboard()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(BookStrideTheme.forestGreen)
                        }
                        
                        // Share via system share sheet
                        Button {
                            shareCard()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(BookStrideTheme.forestGreen)
                        }
                        
                        // Save directly to Photos
                        Button {
                            saveCardToPhotos()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.badge.arrow.down")
                                Text("Save")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(BookStrideTheme.forestGreen)
                            .cornerRadius(16)
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if showingSuccessToast {
                    toastBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .alert("Quote Card", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareImageURL {
                    ActivityViewSheet(activityItems: [url])
                }
            }
            #endif
        }
    }
    
    // MARK: - Preview Canvas
    
    private var cardPreviewCanvas: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: false) {
            VStack {
                Spacer(minLength: 20)
                
                AestheticQuoteCardView(
                    quote: quote,
                    bookTitle: bookTitle,
                    author: author,
                    pageNumber: pageNumber,
                    config: config,
                    isExportMode: false
                )
                
                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, minHeight: 340)
        }
    }
    
    // MARK: - Customization Panel
    
    private var customizationControls: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Theme Swatches
                VStack(alignment: .leading, spacing: 8) {
                    Text("PAPER TEXTURE & THEME")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(BookStrideTheme.mutedSlate)
                        .tracking(1)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(QuoteCardTheme.allCases) { theme in
                                Button {
                                    config.theme = theme
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(theme.backgroundColor)
                                                .frame(width: 38, height: 38)
                                                .overlay(
                                                    Circle()
                                                        .stroke(theme.borderColor, lineWidth: 1)
                                                )
                                                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
                                            
                                            if config.theme == theme {
                                                Circle()
                                                    .stroke(BookStrideTheme.forestGreen, lineWidth: 2.5)
                                                    .frame(width: 44, height: 44)
                                            }
                                        }
                                        
                                        Text(theme.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(config.theme == theme ? BookStrideTheme.forestGreen : BookStrideTheme.mutedSlate)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Typography & Aspect Ratio Row
                HStack(alignment: .top, spacing: 16) {
                    // Typography Style
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TYPOGRAPHY")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(BookStrideTheme.mutedSlate)
                            .tracking(1)
                        
                        Picker("Font Style", selection: $config.fontStyle) {
                            ForEach(QuoteCardFont.allCases) { font in
                                Text(font.rawValue).tag(font)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Aspect Ratio
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RATIO")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(BookStrideTheme.mutedSlate)
                            .tracking(1)
                        
                        Picker("Aspect Ratio", selection: $config.aspectRatio) {
                            ForEach(QuoteCardAspectRatio.allCases) { ratio in
                                Text(ratio.rawValue).tag(ratio)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                // Style Toggles
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        togglePill(
                            title: "Italic",
                            icon: "italic",
                            isOn: $config.isItalic
                        )
                        
                        togglePill(
                            title: config.textAlignment == .center ? "Center" : "Left",
                            icon: config.textAlignment == .center ? "text.aligncenter" : "text.alignleft",
                            isOn: Binding(
                                get: { config.textAlignment == .center },
                                set: { config.textAlignment = $0 ? .center : .leading }
                            )
                        )
                        
                        togglePill(
                            title: "Quotes",
                            icon: "quote.opening",
                            isOn: $config.showQuotationMarks
                        )
                        
                        togglePill(
                            title: "Book Info",
                            icon: "book",
                            isOn: $config.showBookTitle
                        )
                        
                        togglePill(
                            title: "Page No.",
                            icon: "bookmark",
                            isOn: $config.showPageNumber
                        )
                        
                        togglePill(
                            title: "Frame",
                            icon: "square.dashed",
                            isOn: $config.showDecorativeFrame
                        )
                        
                        togglePill(
                            title: "Watermark",
                            icon: "sparkles",
                            isOn: $config.showWatermark
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private func togglePill(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isOn.wrappedValue ? .white : BookStrideTheme.deepCharcoal)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isOn.wrappedValue ? BookStrideTheme.forestGreen : BookStrideTheme.warmIvory)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(BookStrideTheme.borderLight, lineWidth: isOn.wrappedValue ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // Toast banner for feedback
    private var toastBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
            Text(successToastMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.top, 16)
    }
    
    // MARK: - Actions
    
    private func renderExportImage() -> PlatformImage? {
        let exportCard = AestheticQuoteCardView(
            quote: quote,
            bookTitle: bookTitle,
            author: author,
            pageNumber: pageNumber,
            config: config,
            isExportMode: true
        )
        
        return WrappedCardRenderer.renderImage(
            view: exportCard,
            size: config.aspectRatio.exportSize,
            scale: 1.0
        )
    }
    
    private func saveCardToPhotos() {
        guard let image = renderExportImage() else {
            errorMessage = "Unable to render image card."
            showingErrorAlert = true
            return
        }
        
        #if canImport(UIKit)
        PhotoLibrarySaver.saveToPhotos(image: image) { result in
            switch result {
            case .success:
                showToast("Saved to Photos!")
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
        #endif
    }
    
    private func shareCard() {
        guard let image = renderExportImage() else {
            errorMessage = "Unable to render image card."
            showingErrorAlert = true
            return
        }
        
        let filename = "BookStride_Quote_\(Int(Date().timeIntervalSince1970))"
        if let fileURL = WrappedCardRenderer.saveTemporaryPNG(image: image, filename: filename) {
            self.shareImageURL = fileURL
            self.showingShareSheet = true
        } else {
            errorMessage = "Failed to prepare card for sharing."
            showingErrorAlert = true
        }
    }
    
    private func copyImageToClipboard() {
        guard let image = renderExportImage() else {
            errorMessage = "Unable to render image card."
            showingErrorAlert = true
            return
        }
        
        #if canImport(UIKit)
        UIPasteboard.general.image = image
        showToast("Image copied to clipboard!")
        #endif
    }
    
    private func showToast(_ message: String) {
        successToastMessage = message
        withAnimation(.spring()) {
            showingSuccessToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut) {
                showingSuccessToast = false
            }
        }
    }
}

