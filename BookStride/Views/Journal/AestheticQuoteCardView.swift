//
//  AestheticQuoteCardView.swift
//  BookStride
//
//  Minimalist, high-typography image card for saved book quotes and reflections.
//  Supports customizable paper textures, fonts, aspect ratios, and book metadata.
//

import SwiftUI

// MARK: - Themes & Paper Textures

public enum QuoteCardTheme: String, CaseIterable, Identifiable {
    case linenCream = "Linen Cream"
    case midnightObsidian = "Midnight Obsidian"
    case botanicalSage = "Botanical Sage"
    case vintageSepia = "Vintage Sepia"
    case twilightLilac = "Twilight Dusk"
    
    public var id: String { rawValue }
    
    public var backgroundColor: Color {
        switch self {
        case .linenCream:
            return Color(red: 250/255, green: 247/255, blue: 242/255)
        case .midnightObsidian:
            return Color(red: 22/255, green: 23/255, blue: 26/255)
        case .botanicalSage:
            return Color(red: 238/255, green: 242/255, blue: 236/255)
        case .vintageSepia:
            return Color(red: 244/255, green: 236/255, blue: 222/255)
        case .twilightLilac:
            return Color(red: 242/255, green: 239/255, blue: 245/255)
        }
    }
    
    public var primaryTextColor: Color {
        switch self {
        case .linenCream:
            return Color(red: 35/255, green: 33/255, blue: 32/255)
        case .midnightObsidian:
            return Color(red: 248/255, green: 246/255, blue: 240/255)
        case .botanicalSage:
            return Color(red: 28/255, green: 48/255, blue: 38/255)
        case .vintageSepia:
            return Color(red: 50/255, green: 38/255, blue: 30/255)
        case .twilightLilac:
            return Color(red: 40/255, green: 32/255, blue: 52/255)
        }
    }
    
    public var secondaryTextColor: Color {
        switch self {
        case .linenCream:
            return Color(red: 125/255, green: 118/255, blue: 110/255)
        case .midnightObsidian:
            return Color(red: 155/255, green: 160/255, blue: 172/255)
        case .botanicalSage:
            return Color(red: 90/255, green: 115/255, blue: 100/255)
        case .vintageSepia:
            return Color(red: 135/255, green: 110/255, blue: 90/255)
        case .twilightLilac:
            return Color(red: 125/255, green: 112/255, blue: 140/255)
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .linenCream:
            return Color(red: 190/255, green: 140/255, blue: 60/255)
        case .midnightObsidian:
            return Color(red: 200/255, green: 205/255, blue: 218/255)
        case .botanicalSage:
            return Color(red: 65/255, green: 120/255, blue: 85/255)
        case .vintageSepia:
            return Color(red: 175/255, green: 95/255, blue: 50/255)
        case .twilightLilac:
            return Color(red: 165/255, green: 105/255, blue: 145/255)
        }
    }
    
    public var borderColor: Color {
        switch self {
        case .midnightObsidian:
            return Color.white.opacity(0.12)
        default:
            return primaryTextColor.opacity(0.12)
        }
    }
}

// MARK: - Typography

public enum QuoteCardFont: String, CaseIterable, Identifiable {
    case literarySerif = "Serif"
    case modernSans = "Modern Sans"
    case manuscriptMono = "Monospace"
    case poeticRounded = "Rounded"
    
    public var id: String { rawValue }
    
    public var fontDesign: Font.Design {
        switch self {
        case .literarySerif: return .serif
        case .modernSans: return .default
        case .manuscriptMono: return .monospaced
        case .poeticRounded: return .rounded
        }
    }
}

// MARK: - Aspect Ratio

public enum QuoteCardAspectRatio: String, CaseIterable, Identifiable {
    case square = "Square (1:1)"
    case portrait = "Portrait (4:5)"
    case story = "Story (9:16)"
    
    public var id: String { rawValue }
    
    public var ratio: CGFloat {
        switch self {
        case .square: return 1.0
        case .portrait: return 4.0 / 5.0
        case .story: return 9.0 / 16.0
        }
    }
    
    /// Export render dimensions (crisp high-res output)
    public var exportSize: CGSize {
        switch self {
        case .square: return CGSize(width: 1080, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1350)
        case .story: return CGSize(width: 1080, height: 1920)
        }
    }
    
    /// Preview dimensions on iPad
    public var previewSize: CGSize {
        switch self {
        case .square: return CGSize(width: 380, height: 380)
        case .portrait: return CGSize(width: 380, height: 475)
        case .story: return CGSize(width: 320, height: 568)
        }
    }
}

// MARK: - Card Configuration Model

public struct QuoteCardConfig: Equatable {
    public var theme: QuoteCardTheme = .linenCream
    public var fontStyle: QuoteCardFont = .literarySerif
    public var aspectRatio: QuoteCardAspectRatio = .square
    public var isItalic: Bool = true
    public var textAlignment: TextAlignment = .center
    public var showQuotationMarks: Bool = true
    public var showBookTitle: Bool = true
    public var showAuthor: Bool = true
    public var showPageNumber: Bool = true
    public var showWatermark: Bool = true
    public var showDecorativeFrame: Bool = true
    
    public init() {}
}

// MARK: - Card View

public struct AestheticQuoteCardView: View {
    public let quote: String
    public let bookTitle: String?
    public let author: String?
    public let pageNumber: Int?
    public let config: QuoteCardConfig
    public var isExportMode: Bool = false
    
    public init(
        quote: String,
        bookTitle: String? = nil,
        author: String? = nil,
        pageNumber: Int? = nil,
        config: QuoteCardConfig = QuoteCardConfig(),
        isExportMode: Bool = false
    ) {
        self.quote = quote
        self.bookTitle = bookTitle
        self.author = author
        self.pageNumber = pageNumber
        self.config = config
        self.isExportMode = isExportMode
    }
    
    // Adaptive quote font size depending on quote character count and aspect ratio
    private var quoteFontSize: CGFloat {
        let length = quote.count
        let baseSize: CGFloat
        if length < 80 {
            baseSize = 24
        } else if length < 180 {
            baseSize = 20
        } else if length < 320 {
            baseSize = 17
        } else {
            baseSize = 15
        }
        
        // Scale proportionally if rendering for high-resolution export
        if isExportMode {
            return baseSize * 2.8
        }
        return baseSize
    }
    
    private var quoteMarkSize: CGFloat {
        isExportMode ? 90 : 36
    }
    
    private var metadataFontSize: CGFloat {
        isExportMode ? 36 : 13
    }
    
    private var watermarkFontSize: CGFloat {
        isExportMode ? 30 : 11
    }
    
    public var body: some View {
        ZStack {
            // Paper Background
            config.theme.backgroundColor
            
            // Subtle Deckle / Hairline Decorative Frame
            if config.showDecorativeFrame {
                RoundedRectangle(cornerRadius: isExportMode ? 28 : 12)
                    .stroke(config.theme.borderColor, lineWidth: isExportMode ? 3 : 1)
                    .padding(isExportMode ? 36 : 14)
                
                RoundedRectangle(cornerRadius: isExportMode ? 22 : 10)
                    .stroke(config.theme.borderColor.opacity(0.5), lineWidth: isExportMode ? 1.5 : 0.5)
                    .padding(isExportMode ? 44 : 18)
            }
            
            // Card Content
            VStack(spacing: isExportMode ? 36 : 16) {
                Spacer(minLength: 0)
                
                // Decorative Opening Quotation Mark
                if config.showQuotationMarks {
                    Text("“")
                        .font(.system(size: quoteMarkSize, weight: .bold, design: .serif))
                        .foregroundColor(config.theme.accentColor.opacity(0.85))
                        .frame(height: isExportMode ? 40 : 18)
                }
                
                // The Quote Text
                Text(quote.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(
                        .system(
                            size: quoteFontSize,
                            weight: config.fontStyle == .modernSans ? .light : .regular,
                            design: config.fontStyle.fontDesign
                        )
                    )
                    .italic(config.isItalic && config.fontStyle != .manuscriptMono)
                    .foregroundColor(config.theme.primaryTextColor)
                    .multilineTextAlignment(config.textAlignment)
                    .lineSpacing(isExportMode ? 14 : 6)
                    .padding(.horizontal, isExportMode ? 72 : 28)
                
                // Subtle Divider & Metadata
                if hasMetadataToDisplay {
                    VStack(spacing: isExportMode ? 16 : 8) {
                        // Diamond or dash divider
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(config.theme.borderColor)
                                .frame(width: isExportMode ? 60 : 24, height: isExportMode ? 2 : 1)
                            
                            Image(systemName: "diamond.fill")
                                .font(.system(size: isExportMode ? 14 : 6))
                                .foregroundColor(config.theme.accentColor)
                            
                            Rectangle()
                                .fill(config.theme.borderColor)
                                .frame(width: isExportMode ? 60 : 24, height: isExportMode ? 2 : 1)
                        }
                        
                        // Book Title & Author
                        HStack(spacing: 6) {
                            if config.showBookTitle, let title = bookTitle, !title.isEmpty {
                                Text(title)
                                    .font(.system(size: metadataFontSize, weight: .semibold, design: config.fontStyle.fontDesign))
                                    .foregroundColor(config.theme.primaryTextColor)
                                    .lineLimit(2)
                            }
                            
                            if config.showAuthor, let author = author, !author.isEmpty {
                                if config.showBookTitle && bookTitle != nil {
                                    Text("—")
                                        .font(.system(size: metadataFontSize))
                                        .foregroundColor(config.theme.secondaryTextColor)
                                }
                                Text(author)
                                    .font(.system(size: metadataFontSize, weight: .regular, design: config.fontStyle.fontDesign))
                                    .foregroundColor(config.theme.secondaryTextColor)
                            }
                        }
                        
                        // Page Number Badge
                        if config.showPageNumber, let page = pageNumber, page > 0 {
                            Text("PAGE \(page)")
                                .font(.system(size: isExportMode ? 26 : 10, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(config.theme.accentColor)
                                .padding(.horizontal, isExportMode ? 18 : 8)
                                .padding(.vertical, isExportMode ? 6 : 2)
                                .background(config.theme.accentColor.opacity(0.12))
                                .cornerRadius(isExportMode ? 8 : 4)
                        }
                    }
                    .padding(.horizontal, isExportMode ? 64 : 24)
                }
                
                Spacer(minLength: 0)
                
                // Brand Watermark
                if config.showWatermark {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages")
                            .font(.system(size: watermarkFontSize - 1))
                        Text("BookStride")
                            .font(.system(size: watermarkFontSize, weight: .medium, design: .serif))
                            .tracking(1.2)
                    }
                    .foregroundColor(config.theme.secondaryTextColor.opacity(0.65))
                    .padding(.bottom, isExportMode ? 32 : 12)
                }
            }
        }
        .frame(
            width: isExportMode ? config.aspectRatio.exportSize.width : config.aspectRatio.previewSize.width,
            height: isExportMode ? config.aspectRatio.exportSize.height : config.aspectRatio.previewSize.height
        )
        .cornerRadius(isExportMode ? 32 : 14)
        .shadow(
            color: Color.black.opacity(isExportMode ? 0 : 0.08),
            radius: 12,
            x: 0,
            y: 6
        )
    }
    
    private var hasMetadataToDisplay: Bool {
        (config.showBookTitle && bookTitle != nil && !bookTitle!.isEmpty) ||
        (config.showAuthor && author != nil && !author!.isEmpty) ||
        (config.showPageNumber && pageNumber != nil && pageNumber! > 0)
    }
}

