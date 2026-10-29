//
//  ReadingWrappedCardView.swift
//  BookStride
//
//  Locally rendered share cards for Monthly and Yearly Reading Wrapped.
//  Implements pixel-perfect 9:16 vertical story and 1:1 square post layouts.
//

import SwiftUI

public enum WrappedCardFormat: String, CaseIterable, Identifiable {
    case story = "Story (9:16)"
    case post = "Square (1:1)"
    
    public var id: String { rawValue }
    
    public var designSize: CGSize {
        switch self {
        case .story:
            return CGSize(width: 360, height: 640)
        case .post:
            return CGSize(width: 400, height: 400)
        }
    }
    
    public var exportSize: CGSize {
        switch self {
        case .story:
            return CGSize(width: 1080, height: 1920) // Scale 3.0
        case .post:
            return CGSize(width: 1080, height: 1080) // Scale 2.7
        }
    }
    
    public var renderScale: CGFloat {
        switch self {
        case .story: return 3.0
        case .post: return 2.7
        }
    }
}

public enum WrappedThemeStyle: String, CaseIterable, Identifiable {
    case forest = "Forest Green"
    case ivory = "Warm Ivory"
    
    public var id: String { rawValue }
}

public struct WrappedCardCustomization: Equatable {
    public var format: WrappedCardFormat = .story
    public var theme: WrappedThemeStyle = .forest
    public var showCovers: Bool = true
    public var showHighlights: Bool = true
    public var showMostRead: Bool = true
    public var showLongestSession: Bool = true
    
    public init(
        format: WrappedCardFormat = .story,
        theme: WrappedThemeStyle = .forest,
        showCovers: Bool = true,
        showHighlights: Bool = true,
        showMostRead: Bool = true,
        showLongestSession: Bool = true
    ) {
        self.format = format
        self.theme = theme
        self.showCovers = showCovers
        self.showHighlights = showHighlights
        self.showMostRead = showMostRead
        self.showLongestSession = showLongestSession
    }
}

public struct ReadingWrappedCardView: View {
    public let monthlyData: MonthlyWrappedData?
    public let yearlyData: YearlyWrappedData?
    public let config: WrappedCardCustomization
    
    public init(
        monthlyData: MonthlyWrappedData? = nil,
        yearlyData: YearlyWrappedData? = nil,
        config: WrappedCardCustomization
    ) {
        self.monthlyData = monthlyData
        self.yearlyData = yearlyData
        self.config = config
    }
    
    private var isMonthly: Bool {
        monthlyData != nil
    }
    
    private var isForest: Bool {
        config.theme == .forest
    }
    
    // Background and text colors depending on theme
    private var backgroundColor: Color {
        isForest ? Color(red: 24/255, green: 44/255, blue: 34/255) : Color(red: 249/255, green: 247/255, blue: 242/255)
    }
    
    private var cardSurfaceColor: Color {
        isForest ? Color.white.opacity(0.08) : Color.white
    }
    
    private var cardBorderColor: Color {
        isForest ? Color.white.opacity(0.12) : Color(red: 228/255, green: 224/255, blue: 215/255)
    }
    
    private var primaryTextColor: Color {
        isForest ? Color(red: 248/255, green: 247/255, blue: 242/255) : Color(red: 32/255, green: 30/255, blue: 28/255)
    }
    
    private var secondaryTextColor: Color {
        isForest ? Color(red: 195/255, green: 205/255, blue: 198/255) : Color(red: 115/255, green: 110/255, blue: 102/255)
    }
    
    private var accentGold: Color {
        isForest ? Color(red: 224/255, green: 184/255, blue: 118/255) : Color(red: 45/255, green: 90/255, blue: 67/255)
    }
    
    public var body: some View {
        Group {
            if config.format == .story {
                storyLayout
            } else {
                squarePostLayout
            }
        }
        .frame(width: config.format.designSize.width, height: config.format.designSize.height)
        .background(
            ZStack {
                backgroundColor
                
                // Subtle decorative grain/glow
                if isForest {
                    RadialGradient(
                        colors: [Color(red: 35/255, green: 70/255, blue: 52/255), Color.clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 380
                    )
                } else {
                    RadialGradient(
                        colors: [Color(red: 238/255, green: 232/255, blue: 220/255), Color.clear],
                        center: .bottomTrailing,
                        startRadius: 30,
                        endRadius: 360
                    )
                }
            }
        )
        .clipped()
    }
    
    // MARK: - Story (9:16) Layout
    
    private var storyLayout: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 14, weight: .semibold))
                    Text("BOOKSTRIDE")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2.5)
                }
                .foregroundColor(accentGold)
                
                Text(cardTitle)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .lineLimit(1)
                
                Text(isMonthly ? "Monthly Reading Recap" : "Annual Reading Journey")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.top, 28)
            .padding(.bottom, 16)
            
            // Primary Metrics Grid (2x2)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                metricTile(
                    title: "READING TIME",
                    value: totalReadingFormatted,
                    icon: "clock.fill"
                )
                
                metricTile(
                    title: "BOOKS COMPLETED",
                    value: "\(completedBooksCount)",
                    icon: "checkmark.circle.fill"
                )
                
                metricTile(
                    title: "READING DAYS",
                    value: readingDaysFormatted,
                    icon: "calendar"
                )
                
                metricTile(
                    title: isMonthly ? "LONGEST FOCUS" : "PEAK MONTH",
                    value: isMonthly ? longestSessionFormatted : peakMonthFormatted,
                    icon: isMonthly ? "flame.fill" : "chart.line.uptrend.xyaxis"
                )
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
            
            // Book Cover Collage
            if config.showCovers && !collageBooks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(completedBooksCount > 0 ? "BOOKS FINISHED" : "FEATURED READING")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal, 24)
                    
                    coverCollageView(maxCovers: 4, coverWidth: 54, coverHeight: 80)
                        .padding(.horizontal, 22)
                }
                .padding(.bottom, 14)
            }
            
            // Most-read book highlight
            if config.showMostRead, let topBook = mostReadBook {
                HStack(spacing: 12) {
                    BookCoverThumbnail(
                        imageData: topBook.coverImageData,
                        title: topBook.title,
                        author: topBook.author,
                        colorHex: topBook.coverColorHex,
                        iconName: topBook.coverIcon,
                        width: 44,
                        height: 64,
                        cornerRadius: 4
                    )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MOST-READ BOOK")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(accentGold)
                        
                        Text(topBook.title)
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundColor(primaryTextColor)
                            .lineLimit(1)
                        
                        Text(topBook.author.isEmpty ? "\(Formatters.formatDuration(seconds: topBook.totalActiveSeconds, style: .short)) read" : "\(topBook.author) · \(Formatters.formatDuration(seconds: topBook.totalActiveSeconds, style: .short))")
                            .font(.system(size: 11))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardSurfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(cardBorderColor, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
            }
            
            // Highlights & Milestones Banner
            if config.showHighlights {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(accentGold)
                        Text(isMonthly ? "MONTHLY HIGHLIGHT" : "ANNUAL MILESTONES")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(accentGold)
                    }
                    
                    if isMonthly {
                        Text(monthlyData?.dataGroundedHighlight ?? "")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(primaryTextColor)
                            .lineSpacing(2)
                            .lineLimit(3)
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array((yearlyData?.milestones.prefix(2) ?? []).enumerated()), id: \.offset) { _, milestone in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle()
                                        .fill(accentGold)
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 5)
                                    Text(milestone)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(primaryTextColor)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardSurfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(cardBorderColor, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 22)
            }
            
            Spacer(minLength: 8)
            
            // Footer
            HStack {
                Text("Personal Reading Companion")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(secondaryTextColor)
                Spacer()
                Text("bookstride.app")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(accentGold)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Square Post (1:1) Layout
    
    private var squarePostLayout: some View {
        VStack(spacing: 12) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 12, weight: .semibold))
                        Text("BOOKSTRIDE")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(2.0)
                    }
                    .foregroundColor(accentGold)
                    
                    Text(cardTitle)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isMonthly ? "WRAPPED" : "YEAR IN BOOKS")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(accentGold)
                    
                    Text("\(completedBooksCount) Completed")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Compact 3-Column Metrics Bar
            HStack(spacing: 8) {
                compactMetricCell(title: "TOTAL TIME", value: totalReadingFormatted)
                compactMetricCell(title: "READING DAYS", value: readingDaysFormatted)
                compactMetricCell(
                    title: isMonthly ? "LONGEST" : "PEAK MONTH",
                    value: isMonthly ? longestSessionFormatted : peakMonthFormatted
                )
            }
            .padding(.horizontal, 20)
            
            // Collage + Most-Read Row
            if config.showCovers && !collageBooks.isEmpty {
                HStack(alignment: .center, spacing: 14) {
                    coverCollageView(maxCovers: 3, coverWidth: 50, coverHeight: 74)
                    
                    if config.showMostRead, let topBook = mostReadBook {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TOP BOOK")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundColor(accentGold)
                            
                            Text(topBook.title)
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundColor(primaryTextColor)
                                .lineLimit(2)
                            
                            if !topBook.author.isEmpty {
                                Text(topBook.author)
                                    .font(.system(size: 10))
                                    .foregroundColor(secondaryTextColor)
                                    .lineLimit(1)
                            }
                            
                            Text(Formatters.formatDuration(seconds: topBook.totalActiveSeconds, style: .short))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(accentGold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardSurfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(cardBorderColor, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
            }
            
            // Highlights Line
            if config.showHighlights {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(accentGold)
                    
                    Text(summaryHighlightText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cardSurfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(cardBorderColor, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
            }
            
            Spacer(minLength: 4)
            
            // Footer
            HStack {
                Text("Personal Reading Companion")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(secondaryTextColor)
                Spacer()
                Text("bookstride.app")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(accentGold)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Components
    
    private func metricTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(accentGold)
                
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundColor(secondaryTextColor)
            }
            
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .monospaced))
                .foregroundColor(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardSurfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
    }
    
    private func compactMetricCell(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(secondaryTextColor)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardSurfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
    }
    
    private func coverCollageView(maxCovers: Int, coverWidth: CGFloat, coverHeight: CGFloat) -> some View {
        let booksToShow = Array(collageBooks.prefix(maxCovers))
        return HStack(spacing: 10) {
            ForEach(booksToShow) { book in
                BookCoverThumbnail(
                    imageData: book.coverImageData,
                    title: book.title,
                    author: book.author,
                    colorHex: book.coverColorHex,
                    iconName: book.coverIcon,
                    width: coverWidth,
                    height: coverHeight,
                    cornerRadius: 5
                )
                .shadow(color: Color.black.opacity(isForest ? 0.4 : 0.15), radius: 4, x: 0, y: 2)
            }
            
            if collageBooks.count > maxCovers {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(cardSurfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(cardBorderColor, lineWidth: 1)
                        )
                        .frame(width: coverWidth, height: coverHeight)
                    
                    VStack(spacing: 2) {
                        Text("+\(collageBooks.count - maxCovers)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(accentGold)
                        Text("MORE")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundColor(secondaryTextColor)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var cardTitle: String {
        if let m = monthlyData {
            return m.title
        } else if let y = yearlyData {
            return "\(y.year)"
        }
        return "Reading Wrapped"
    }
    
    private var totalReadingFormatted: String {
        let secs = isMonthly ? (monthlyData?.totalReadingSeconds ?? 0) : (yearlyData?.totalReadingSeconds ?? 0)
        return Formatters.formatDuration(seconds: secs, style: .short)
    }
    
    private var completedBooksCount: Int {
        if let m = monthlyData {
            return m.completedBooks.count
        } else if let y = yearlyData {
            return y.uniqueBooksCompleted.count
        }
        return 0
    }
    
    private var readingDaysFormatted: String {
        if let m = monthlyData {
            return "\(m.readingDaysCount) / \(m.totalDaysInMonth)"
        } else if let y = yearlyData {
            return "\(y.readingDaysCount) Days"
        }
        return "0 Days"
    }
    
    private var longestSessionFormatted: String {
        let secs = monthlyData?.longestSessionSeconds ?? 0
        guard secs > 0 else { return "0m" }
        return Formatters.formatDuration(seconds: secs, style: .short)
    }
    
    private var peakMonthFormatted: String {
        if let peak = yearlyData?.mostProductiveMonthName, !peak.isEmpty {
            return peak
        }
        return "None"
    }
    
    private var collageBooks: [WrappedBookSummary] {
        if let m = monthlyData {
            if !m.completedBooks.isEmpty {
                return m.completedBooks
            } else if let top = m.mostReadBook {
                return [top]
            }
            return []
        } else if let y = yearlyData {
            if !y.uniqueBooksCompleted.isEmpty {
                return y.uniqueBooksCompleted
            } else if let top = y.mostReadBook {
                return [top]
            }
            return []
        }
        return []
    }
    
    private var mostReadBook: WrappedBookSummary? {
        isMonthly ? monthlyData?.mostReadBook : yearlyData?.mostReadBook
    }
    
    private var summaryHighlightText: String {
        if let m = monthlyData {
            return m.dataGroundedHighlight
        } else if let y = yearlyData {
            return y.milestones.first ?? "Focused reading in \(y.year)."
        }
        return "Your personal reading recap."
    }
}

