//
//  WoodenBookshelfView.swift
//  BookStride
//
//  Rich multi-tier virtual wooden bookshelf displaying books by their upright
//  colored spines, with polished wood planking, beveled trim, and ambient shadows.
//  Dynamically wraps books onto lower racks when horizontal shelf space is exhausted.
//

import SwiftUI

public struct BookshelfWidthPreferenceKey: PreferenceKey {
    public static var defaultValue: CGFloat = 800
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public struct WoodenBookshelfView: View {
    public let books: [Book]
    public var availableWidth: CGFloat?
    public var onSelectBook: (Book) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var measuredWidth: CGFloat = 800
    
    public init(
        books: [Book],
        availableWidth: CGFloat? = nil,
        onSelectBook: @escaping (Book) -> Void = { _ in }
    ) {
        self.books = books
        self.availableWidth = availableWidth
        self.onSelectBook = onSelectBook
    }
    
    private var effectiveWidth: CGFloat {
        if let availableWidth, availableWidth > 100 {
            return availableWidth
        }
        return measuredWidth > 100 ? measuredWidth : 800
    }
    
    // Wood plank palette
    private var woodTopSurface: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 65/255, green: 42/255, blue: 28/255),
                    Color(red: 48/255, green: 30/255, blue: 20/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 145/255, green: 98/255, blue: 64/255),
                    Color(red: 115/255, green: 74/255, blue: 46/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var woodFrontBevel: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 82/255, green: 54/255, blue: 38/255),
                    Color(red: 36/255, green: 22/255, blue: 14/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 165/255, green: 112/255, blue: 74/255),
                    Color(red: 90/255, green: 58/255, blue: 35/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    public var body: some View {
        VStack(spacing: 38) {
            if books.isEmpty {
                emptyBookshelfView
                    .frame(minHeight: 280)
            } else {
                let shelves = organizeShelves(books: books, availableWidth: effectiveWidth)
                ForEach(Array(shelves.enumerated()), id: \.offset) { index, rowBooks in
                    shelfRow(books: rowBooks, shelfIndex: index)
                }
                
                // If there is only 1 filled shelf, render a companion lower rack to maintain
                // the handsome, multi-tier library bookcase aesthetic
                if shelves.count == 1 {
                    emptyShelfRow(shelfIndex: 1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 48)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: BookshelfWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(BookshelfWidthPreferenceKey.self) { newWidth in
            if newWidth > 50 && abs(newWidth - measuredWidth) > 2 {
                measuredWidth = newWidth
            }
        }
    }
    
    // MARK: - Dynamic Shelf Packing Logic
    
    /// Packs books onto shelves greedily based on the actual measured spine width of each book.
    /// When a book does not fit within the current shelf row's width, it wraps to the next bottom rack.
    private func organizeShelves(books: [Book], availableWidth: CGFloat) -> [[Book]] {
        guard !books.isEmpty else { return [] }
        
        // 40pt outer horizontal padding + 28pt shelf horizontal padding + 32pt bookends + 8pt margins = 108pt overhead
        let usableWidth = max(200, availableWidth - 108)
        var shelves: [[Book]] = []
        var currentShelf: [Book] = []
        var currentShelfWidth: CGFloat = 0
        let bookSpacing: CGFloat = 4
        
        for book in books {
            let bookWidth = BookSpineView.spineWidth(for: book)
            let neededWidth = currentShelf.isEmpty ? bookWidth : (bookWidth + bookSpacing)
            
            if currentShelf.isEmpty || (currentShelfWidth + neededWidth <= usableWidth) {
                currentShelf.append(book)
                currentShelfWidth += neededWidth
            } else {
                // Shelf is full: wrap to next bottom rack
                shelves.append(currentShelf)
                currentShelf = [book]
                currentShelfWidth = bookWidth
            }
        }
        
        if !currentShelf.isEmpty {
            shelves.append(currentShelf)
        }
        
        return shelves
    }
    
    // MARK: - Shelf Row
    
    private func shelfRow(books: [Book], shelfIndex: Int) -> some View {
        VStack(spacing: 0) {
            // Upright Spines sitting on the shelf
            HStack(alignment: .bottom, spacing: 4) {
                // Left decorative brass bookend
                bookendView(isLeft: true)
                
                ForEach(books) { book in
                    BookSpineView(book: book) {
                        onSelectBook(book)
                    }
                }
                
                // Right decorative brass bookend hugging the books upright
                bookendView(isLeft: false)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            
            // Handcrafted Wooden Shelf Plank
            woodenPlankView
        }
    }
    
    // Empty companion rack
    private func emptyShelfRow(shelfIndex: Int) -> some View {
        VStack(spacing: 0) {
            // Empty space where future books will rest
            Color.clear
                .frame(height: 70)
            
            woodenPlankView
        }
    }
    
    // Polished Wooden Plank with top highlight, wood grain fill, beveled face, and deep shadow
    private var woodenPlankView: some View {
        VStack(spacing: 0) {
            // Top shelf surface highlight line
            Rectangle()
                .fill(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.28))
                .frame(height: 1.5)
            
            // Shelf Top Plate
            Rectangle()
                .fill(woodTopSurface)
                .frame(height: 10)
            
            // Shelf Front Beveled Ledge
            Rectangle()
                .fill(woodFrontBevel)
                .frame(height: 16)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.black.opacity(0.45))
                            .frame(height: 1)
                    }
                )
        }
        .cornerRadius(4)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.22), radius: 8, x: 0, y: 6)
    }
    
    // Decorative brass/bronze bookend support
    private func bookendView(isLeft: Bool) -> some View {
        ZStack(alignment: isLeft ? .bottomLeading : .bottomTrailing) {
            Path { path in
                if isLeft {
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 16, y: 110))
                    path.addLine(to: CGPoint(x: 0, y: 110))
                } else {
                    path.move(to: CGPoint(x: 16, y: 0))
                    path.addLine(to: CGPoint(x: 16, y: 110))
                    path.addLine(to: CGPoint(x: 0, y: 110))
                }
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 220/255, green: 180/255, blue: 90/255),
                        Color(red: 140/255, green: 105/255, blue: 40/255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 16, height: 110)
            .opacity(0.85)
            .shadow(color: Color.black.opacity(0.25), radius: 2, x: isLeft ? 1 : -1, y: 0)
        }
    }
    
    // Empty state rendered as a quiet, polished bookcase
    private var emptyBookshelfView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)
            
            Image(systemName: "books.vertical")
                .font(.system(size: 46))
                .foregroundColor(BookStrideTheme.mutedSlate.opacity(0.6))
            
            Text("Bookshelf is Empty")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundColor(BookStrideTheme.deepCharcoal)
            
            Text("Your finished stories and active books will stand upright\nwith embossed foil lettering here.")
                .font(.subheadline)
                .foregroundColor(BookStrideTheme.mutedSlate)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Spacer(minLength: 40)
            
            // Empty wooden plank at the bottom
            woodenPlankView
        }
        .padding()
    }
}
