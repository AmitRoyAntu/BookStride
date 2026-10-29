//
//  BookCoverThumbnail.swift
//  BookStride
//
//  Stylized book cover view with image support and customizable journal palettes.
//

import SwiftUI

public struct BookCoverThumbnail: View {
    public var imageData: Data?
    public var title: String
    public var author: String
    public var colorHex: String
    public var iconName: String
    public var width: CGFloat
    public var height: CGFloat
    public var cornerRadius: CGFloat
    
    public init(
        imageData: Data? = nil,
        title: String,
        author: String = "",
        colorHex: String = "forest",
        iconName: String = "book.closed",
        width: CGFloat = 110,
        height: CGFloat = 165,
        cornerRadius: CGFloat = 8
    ) {
        self.imageData = imageData
        self.title = title
        self.author = author
        self.colorHex = colorHex
        self.iconName = iconName
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    private var baseColor: Color {
        BookStrideTheme.bookCoverColors[colorHex] ?? BookStrideTheme.forestGreen
    }
    
    public var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                // Procedural stylized hardcover book aesthetic
                ZStack {
                    baseColor
                    
                    // Subtle embossed linen overlay
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.black.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Book spine highlight on the left edge
                    HStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.black.opacity(0.25),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, width * 0.06))
                        Spacer()
                    }
                    
                    // Book typography & ornament
                    VStack(spacing: 6) {
                        Spacer()
                        
                        Image(systemName: iconName)
                            .font(.system(size: width * 0.2, weight: .light))
                            .foregroundColor(Color.white.opacity(0.85))
                            .padding(.bottom, 4)
                        
                        Text(title)
                            .font(.system(size: max(11, width * 0.11), weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 8)
                        
                        if !author.isEmpty {
                            Text(author)
                                .font(.system(size: max(9, width * 0.085), weight: .medium, design: .serif))
                                .foregroundColor(Color.white.opacity(0.8))
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                        }
                        
                        Spacer()
                    }
                    .padding(4)
                }
                .frame(width: width, height: height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 5, x: 2, y: 3)
    }
}

