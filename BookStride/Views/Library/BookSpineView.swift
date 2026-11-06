//
//  BookSpineView.swift
//  BookStride
//
//  Realistic 3D physical book spine with proportional page thickness,
//  cylindrical lighting, embossed leather ribs, and gold/silver foil serif typography.
//

import SwiftUI

public struct BookSpineView: View {
    public let book: Book
    public var onSelect: () -> Void
    
    @State private var isHovered: Bool = false
    
    public init(book: Book, onSelect: @escaping () -> Void = {}) {
        self.book = book
        self.onSelect = onSelect
    }
    
    // Dynamic height with organic variance based on book title hash
    private var spineHeight: CGFloat {
        let variance = abs(book.title.hashValue % 4)
        switch variance {
        case 0: return 192
        case 1: return 200
        case 2: return 208
        default: return 214
        }
    }
    
    // Dynamic width proportional to total page count
    public static func spineWidth(for book: Book) -> CGFloat {
        guard let pages = book.totalPages, pages > 0 else {
            return 44
        }
        if pages <= 180 {
            return 34
        } else if pages <= 350 {
            return 44
        } else if pages <= 600 {
            return 54
        } else if pages <= 900 {
            return 64
        } else {
            return 74
        }
    }
    
    private var spineWidth: CGFloat {
        Self.spineWidth(for: book)
    }
    
    private var baseColor: Color {
        BookStrideTheme.bookCoverColors[book.coverColorHex] ?? BookStrideTheme.forestGreen
    }
    
    // Choice between shimmering gold foil and silver-platinum foil
    private var isGoldFoil: Bool {
        book.coverColorHex != "slate" && book.coverColorHex != "navy"
    }
    
    private var foilGradient: LinearGradient {
        if isGoldFoil {
            return LinearGradient(
                colors: [
                    Color(red: 255/255, green: 240/255, blue: 180/255),
                    Color(red: 218/255, green: 172/255, blue: 68/255),
                    Color(red: 245/255, green: 225/255, blue: 155/255),
                    Color(red: 195/255, green: 150/255, blue: 45/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 250/255, green: 250/255, blue: 255/255),
                    Color(red: 210/255, green: 215/255, blue: 225/255),
                    Color(red: 240/255, green: 242/255, blue: 248/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    public var body: some View {
        Button {
            onSelect()
        } label: {
            ZStack(alignment: .bottom) {
                // Main Spine Body
                ZStack {
                    // Base Hardcover Color
                    baseColor
                    
                    // 3D Cylindrical Spine Shading (highlights down the center, deep curvature at edges)
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.45), location: 0.0),
                            .init(color: Color.black.opacity(0.12), location: 0.15),
                            .init(color: Color.white.opacity(0.24), location: 0.45),
                            .init(color: Color.white.opacity(0.08), location: 0.65),
                            .init(color: Color.black.opacity(0.40), location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    // Embossed Bookbinding Ribs (Raised horizontal bands)
                    VStack {
                        embossedBand
                            .padding(.top, 22)
                        
                        embossedBand
                            .padding(.top, 8)
                        
                        Spacer()
                        
                        embossedBand
                            .padding(.bottom, 8)
                        
                        embossedBand
                            .padding(.bottom, 22)
                    }
                    
                    // Foil Lettering & Typography
                    VStack(spacing: 4) {
                        // Top decorative star / ornament
                        if book.status == .finished {
                            Image(systemName: "sparkle")
                                .font(.system(size: 8))
                                .foregroundStyle(foilGradient)
                                .padding(.top, 28)
                        } else {
                            Circle()
                                .fill(foilGradient)
                                .frame(width: 4, height: 4)
                                .padding(.top, 28)
                        }
                        
                        Spacer(minLength: 4)
                        
                        // Rotated Vertical Spine Title (Supports Multiple Lines!)
                        titleView
                        
                        Spacer(minLength: 4)
                        
                        // Author Name (Strictly separated at the bottom)
                        if !book.author.isEmpty {
                            authorView
                        }
                        
                        // Bottom emblem: rating or finished symbol
                        if let r = book.rating, r > 0 {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(foilGradient)
                                .padding(.bottom, 28)
                        } else {
                            Rectangle()
                                .fill(foilGradient.opacity(0.6))
                                .frame(width: spineWidth * 0.35, height: 1)
                                .padding(.bottom, 28)
                        }
                    }
                    .frame(width: spineWidth, height: spineHeight)
                }
                .frame(width: spineWidth, height: spineHeight)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                )
                // Spine drop shadow onto adjacent books
                .shadow(color: Color.black.opacity(0.35), radius: isHovered ? 8 : 4, x: 2, y: isHovered ? -4 : 0)
                .offset(y: isHovered ? -12 : 0)
                
                // Bookmark Ribbon dangling below currently reading books
                if book.status == .currentlyReading {
                    Rectangle()
                        .fill(BookStrideTheme.streakAmber)
                        .frame(width: 6, height: 16)
                        .offset(x: spineWidth * 0.2, y: 14)
                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 1, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
    }
    
    // Rotated Title: Supports 1 or 2 lines cleanly without overflowing
    private var titleView: some View {
        let titleLength = min(116, spineHeight * 0.54)
        let maxThickness = spineWidth - 6
        let fontSize = max(9, min(12, spineWidth * 0.24))
        
        return Text(book.title.uppercased())
            .font(.system(size: fontSize, weight: .bold, design: .serif))
            .foregroundStyle(foilGradient)
            .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0.5, y: 0.5)
            .lineLimit(2)
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.75)
            .frame(width: titleLength, height: maxThickness)
            .rotationEffect(.degrees(-90))
            .frame(width: spineWidth, height: titleLength)
    }
    
    // Rotated Author: Strict bounded box at the base of the spine
    private var authorView: some View {
        let authorLength: CGFloat = 40
        let maxThickness = spineWidth - 6
        
        return Text(book.author)
            .font(.system(size: 8, weight: .medium, design: .serif))
            .foregroundStyle(foilGradient.opacity(0.85))
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .frame(width: authorLength, height: maxThickness)
            .rotationEffect(.degrees(-90))
            .frame(width: spineWidth, height: authorLength)
    }
    
    // Decorative embossed horizontal rib on the spine
    private var embossedBand: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .frame(height: 1)
            Rectangle()
                .fill(foilGradient.opacity(0.75))
                .frame(height: 1.5)
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(height: 0.8)
        }
        .frame(width: spineWidth)
    }
}

