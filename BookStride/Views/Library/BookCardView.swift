//
//  BookCardView.swift
//  BookStride
//
//  Grid card representation of a book for the iPad library view.
//

import SwiftUI

public struct BookCardView: View {
    public var book: Book
    public var onMarkFinished: () -> Void
    public var onDelete: () -> Void
    
    public init(
        book: Book,
        onMarkFinished: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.book = book
        self.onMarkFinished = onMarkFinished
        self.onDelete = onDelete
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Book cover
            BookCoverThumbnail(
                imageData: book.coverImageData,
                title: book.title,
                author: book.author,
                colorHex: book.coverColorHex,
                iconName: book.coverIcon,
                width: LayoutConstants.bookGridCardWidth,
                height: LayoutConstants.bookGridCardHeight,
                cornerRadius: 8
            )
            .overlay(alignment: .topTrailing) {
                if book.status == .finished {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(BookStrideTheme.forestGreen)
                        .background(Circle().fill(Color.white).padding(2))
                        .offset(x: -8, y: 8)
                }
            }
            
            // Title & Author
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .topLeading)
                
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                        .lineLimit(1)
                }
            }
            
            // Progress Bar & Page Stats
            if let total = book.totalPages, total > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: book.progressFraction)
                        .tint(BookStrideTheme.forestGreen)
                    
                    HStack {
                        Text("\(book.currentPage ?? 0) / \(total) p.")
                            .font(.caption2)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        Spacer()
                        Text(Formatters.formatPercentage(book.progressFraction))
                            .font(.caption2.weight(.medium))
                            .foregroundColor(BookStrideTheme.forestGreen)
                    }
                }
            } else if let current = book.currentPage, current > 0 {
                Text("Page \(current)")
                    .font(.caption2)
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
        }
        .frame(width: LayoutConstants.bookGridCardWidth)
        .contextMenu {
            if book.status != .finished {
                Button {
                    onMarkFinished()
                } label: {
                    Label("Mark as Finished", systemImage: "checkmark.circle")
                }
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Book", systemImage: "trash")
            }
        }
    }
}

