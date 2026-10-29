//
//  ReadingWrappedService.swift
//  BookStride
//
//  Data aggregation service for Monthly and Yearly Reading Wrapped cards.
//  Strictly grounded in persisted reading sessions and library books.
//

import Foundation

public struct WrappedBookSummary: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let author: String
    public let coverColorHex: String
    public let coverIcon: String
    public let coverImageData: Data?
    public let totalActiveSeconds: Int
    public let pagesRead: Int
    public let rating: Int?
    public let finishDate: Date?
    
    public init(
        id: UUID,
        title: String,
        author: String = "",
        coverColorHex: String = "forest",
        coverIcon: String = "book.closed",
        coverImageData: Data? = nil,
        totalActiveSeconds: Int = 0,
        pagesRead: Int = 0,
        rating: Int? = nil,
        finishDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverColorHex = coverColorHex
        self.coverIcon = coverIcon
        self.coverImageData = coverImageData
        self.totalActiveSeconds = totalActiveSeconds
        self.pagesRead = pagesRead
        self.rating = rating
        self.finishDate = finishDate
    }
}

public struct MonthlyWrappedData: Equatable {
    public let month: Int
    public let year: Int
    public let title: String
    public let totalReadingSeconds: Int
    public let readingDaysCount: Int
    public let totalDaysInMonth: Int
    public let longestSessionSeconds: Int
    public let longestSessionBookTitle: String?
    public let mostReadBook: WrappedBookSummary?
    public let completedBooks: [WrappedBookSummary]
    public let totalSessionsCount: Int
    public let totalPagesRead: Int
    public let dataGroundedHighlight: String
    public let isEmpty: Bool
    
    public init(
        month: Int,
        year: Int,
        title: String,
        totalReadingSeconds: Int,
        readingDaysCount: Int,
        totalDaysInMonth: Int,
        longestSessionSeconds: Int,
        longestSessionBookTitle: String?,
        mostReadBook: WrappedBookSummary?,
        completedBooks: [WrappedBookSummary],
        totalSessionsCount: Int,
        totalPagesRead: Int,
        dataGroundedHighlight: String,
        isEmpty: Bool
    ) {
        self.month = month
        self.year = year
        self.title = title
        self.totalReadingSeconds = totalReadingSeconds
        self.readingDaysCount = readingDaysCount
        self.totalDaysInMonth = totalDaysInMonth
        self.longestSessionSeconds = longestSessionSeconds
        self.longestSessionBookTitle = longestSessionBookTitle
        self.mostReadBook = mostReadBook
        self.completedBooks = completedBooks
        self.totalSessionsCount = totalSessionsCount
        self.totalPagesRead = totalPagesRead
        self.dataGroundedHighlight = dataGroundedHighlight
        self.isEmpty = isEmpty
    }
}

public struct YearlyWrappedData: Equatable {
    public let year: Int
    public let title: String
    public let totalReadingSeconds: Int
    public let readingDaysCount: Int
    public let totalDaysInYear: Int
    public let uniqueBooksCompleted: [WrappedBookSummary]
    public let booksStartedCount: Int
    public let currentlyReadingCount: Int
    public let mostReadBook: WrappedBookSummary?
    public let mostProductiveMonthName: String?
    public let mostProductiveMonthSeconds: Int
    public let longestSessionSeconds: Int
    public let totalSessionsCount: Int
    public let totalPagesRead: Int
    public let milestones: [String]
    public let isEmpty: Bool
    
    public init(
        year: Int,
        title: String,
        totalReadingSeconds: Int,
        readingDaysCount: Int,
        totalDaysInYear: Int,
        uniqueBooksCompleted: [WrappedBookSummary],
        booksStartedCount: Int,
        currentlyReadingCount: Int,
        mostReadBook: WrappedBookSummary?,
        mostProductiveMonthName: String?,
        mostProductiveMonthSeconds: Int,
        longestSessionSeconds: Int,
        totalSessionsCount: Int,
        totalPagesRead: Int,
        milestones: [String],
        isEmpty: Bool
    ) {
        self.year = year
        self.title = title
        self.totalReadingSeconds = totalReadingSeconds
        self.readingDaysCount = readingDaysCount
        self.totalDaysInYear = totalDaysInYear
        self.uniqueBooksCompleted = uniqueBooksCompleted
        self.booksStartedCount = booksStartedCount
        self.currentlyReadingCount = currentlyReadingCount
        self.mostReadBook = mostReadBook
        self.mostProductiveMonthName = mostProductiveMonthName
        self.mostProductiveMonthSeconds = mostProductiveMonthSeconds
        self.longestSessionSeconds = longestSessionSeconds
        self.totalSessionsCount = totalSessionsCount
        self.totalPagesRead = totalPagesRead
        self.milestones = milestones
        self.isEmpty = isEmpty
    }
}

public enum ReadingWrappedService {
    
    // MARK: - Monthly Wrapped Calculation
    
    public static func computeMonthlyWrapped(
        month: Int,
        year: Int,
        sessions: [ReadingSessionDTO],
        books: [BookDTO],
        calendar: Calendar = DateUtilities.defaultCalendar
    ) -> MonthlyWrappedData {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 0, minute: 0, second: 0)) else {
            return emptyMonthlyData(month: month, year: year)
        }
        
        let daysRange = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let totalDaysInMonth = daysRange.count
        guard let monthEnd = calendar.date(byAdding: .day, value: totalDaysInMonth, to: monthStart)?.addingTimeInterval(-0.001) else {
            return emptyMonthlyData(month: month, year: year)
        }
        
        // Month title (e.g., "October 2026")
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        let monthTitle = formatter.string(from: monthStart)
        
        let completedSessions = sessions.filter { $0.status == SessionStatus.completed.rawValue }
        
        var totalReadingSeconds = 0
        var activeDaysSet = Set<Date>()
        var bookTimeMap: [UUID: Int] = [:]
        var bookPagesMap: [UUID: Int] = [:]
        var longestSessionSeconds = 0
        var longestSessionBookId: UUID? = nil
        var totalSessionsCount = 0
        var totalPagesRead = 0
        
        for session in completedSessions {
            let activeSec = session.activeSeconds
            guard activeSec > 0 else { continue }
            
            let effectiveEnd = session.endedAt ?? session.startedAt.addingTimeInterval(Double(activeSec))
            
            // Check for overlap with the target month
            guard session.startedAt <= monthEnd && effectiveEnd >= monthStart else {
                continue
            }
            
            // Session started within target month
            if session.startedAt >= monthStart && session.startedAt <= monthEnd {
                totalSessionsCount += 1
                if activeSec > longestSessionSeconds {
                    longestSessionSeconds = activeSec
                    longestSessionBookId = session.bookId
                }
                if let sPage = session.startPage, let ePage = session.endPage, ePage > sPage {
                    let diff = ePage - sPage
                    totalPagesRead += diff
                    if let bId = session.bookId {
                        bookPagesMap[bId, default: 0] += diff
                    }
                }
            }
            
            // Accurate day allocation using cross-midnight splitting
            let allocations = DateUtilities.splitSessionAcrossDays(
                startedAt: session.startedAt,
                endedAt: effectiveEnd,
                activeSeconds: activeSec,
                calendar: calendar
            )
            
            for alloc in allocations {
                if alloc.date >= monthStart && alloc.date <= monthEnd {
                    totalReadingSeconds += alloc.activeSeconds
                    if alloc.activeSeconds >= 60 {
                        activeDaysSet.insert(alloc.date)
                    }
                    if let bId = session.bookId {
                        bookTimeMap[bId, default: 0] += alloc.activeSeconds
                    }
                }
            }
        }
        
        // Books completed during this month (ensuring unique books, preventing duplicate counts)
        var uniqueCompletedBookIds = Set<UUID>()
        var completedSummaries: [WrappedBookSummary] = []
        
        for b in books where b.status == ReadingStatus.finished.rawValue {
            let isCompletedInMonth: Bool
            if let fDate = b.finishDate {
                isCompletedInMonth = (fDate >= monthStart && fDate <= monthEnd)
            } else {
                // If finishDate is unrecorded, check if book had a completed session in this month
                // and its current page equals or exceeds total pages
                let hasSessionInMonth = completedSessions.contains { s in
                    s.bookId == b.id && s.startedAt >= monthStart && s.startedAt <= monthEnd
                }
                let pagesReached = (b.currentPage ?? 0) >= (b.totalPages ?? 1)
                isCompletedInMonth = hasSessionInMonth && pagesReached
            }
            
            if isCompletedInMonth && !uniqueCompletedBookIds.contains(b.id) {
                uniqueCompletedBookIds.insert(b.id)
                let bookSecs = bookTimeMap[b.id] ?? 0
                let bookPages = bookPagesMap[b.id] ?? 0
                completedSummaries.append(
                    WrappedBookSummary(
                        id: b.id,
                        title: b.title,
                        author: b.author,
                        coverColorHex: b.coverColorHex,
                        coverIcon: b.coverIcon,
                        totalActiveSeconds: bookSecs,
                        pagesRead: bookPages,
                        rating: b.rating,
                        finishDate: b.finishDate
                    )
                )
            }
        }
        
        // Most-read book based strictly on session data in this month
        var mostReadBook: WrappedBookSummary? = nil
        if let topBookEntry = bookTimeMap.max(by: { $0.value < $1.value }), topBookEntry.value > 0 {
            if let matchedBook = books.first(where: { $0.id == topBookEntry.key }) {
                mostReadBook = WrappedBookSummary(
                    id: matchedBook.id,
                    title: matchedBook.title,
                    author: matchedBook.author,
                    coverColorHex: matchedBook.coverColorHex,
                    coverIcon: matchedBook.coverIcon,
                    totalActiveSeconds: topBookEntry.value,
                    pagesRead: bookPagesMap[matchedBook.id] ?? 0,
                    rating: matchedBook.rating,
                    finishDate: matchedBook.finishDate
                )
            }
        }
        
        let longestSessionTitle = books.first(where: { $0.id == longestSessionBookId })?.title
        let isEmpty = (totalReadingSeconds == 0 && completedSummaries.isEmpty)
        
        // Formulate a short, honest, data-grounded highlight
        let highlight = formulateMonthlyHighlight(
            completedCount: completedSummaries.count,
            readingDays: activeDaysSet.count,
            totalDays: totalDaysInMonth,
            totalSeconds: totalReadingSeconds,
            longestSessionSeconds: longestSessionSeconds,
            longestBookTitle: longestSessionTitle,
            monthTitle: monthTitle
        )
        
        return MonthlyWrappedData(
            month: month,
            year: year,
            title: monthTitle,
            totalReadingSeconds: totalReadingSeconds,
            readingDaysCount: activeDaysSet.count,
            totalDaysInMonth: totalDaysInMonth,
            longestSessionSeconds: longestSessionSeconds,
            longestSessionBookTitle: longestSessionTitle,
            mostReadBook: mostReadBook,
            completedBooks: completedSummaries,
            totalSessionsCount: totalSessionsCount,
            totalPagesRead: totalPagesRead,
            dataGroundedHighlight: highlight,
            isEmpty: isEmpty
        )
    }
    
    // MARK: - Yearly Wrapped Calculation
    
    public static func computeYearlyWrapped(
        year: Int,
        sessions: [ReadingSessionDTO],
        books: [BookDTO],
        calendar: Calendar = DateUtilities.defaultCalendar
    ) -> YearlyWrappedData {
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1, hour: 0, minute: 0, second: 0)),
              let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)?.addingTimeInterval(-0.001) else {
            return emptyYearlyData(year: year)
        }
        
        let daysRange = calendar.range(of: .day, in: .year, for: yearStart) ?? 1..<366
        let totalDaysInYear = daysRange.count
        let yearTitle = "\(year) Reading Wrapped"
        
        let completedSessions = sessions.filter { $0.status == SessionStatus.completed.rawValue }
        
        var totalReadingSeconds = 0
        var activeDaysSet = Set<Date>()
        var bookTimeMap: [UUID: Int] = [:]
        var bookPagesMap: [UUID: Int] = [:]
        var monthTimeMap: [Int: Int] = [:] // month index (1-12) -> seconds
        var longestSessionSeconds = 0
        var totalSessionsCount = 0
        var totalPagesRead = 0
        
        for session in completedSessions {
            let activeSec = session.activeSeconds
            guard activeSec > 0 else { continue }
            
            let effectiveEnd = session.endedAt ?? session.startedAt.addingTimeInterval(Double(activeSec))
            guard session.startedAt <= yearEnd && effectiveEnd >= yearStart else { continue }
            
            if session.startedAt >= yearStart && session.startedAt <= yearEnd {
                totalSessionsCount += 1
                if activeSec > longestSessionSeconds {
                    longestSessionSeconds = activeSec
                }
                if let sPage = session.startPage, let ePage = session.endPage, ePage > sPage {
                    let diff = ePage - sPage
                    totalPagesRead += diff
                    if let bId = session.bookId {
                        bookPagesMap[bId, default: 0] += diff
                    }
                }
            }
            
            let allocations = DateUtilities.splitSessionAcrossDays(
                startedAt: session.startedAt,
                endedAt: effectiveEnd,
                activeSeconds: activeSec,
                calendar: calendar
            )
            
            for alloc in allocations {
                if alloc.date >= yearStart && alloc.date <= yearEnd {
                    totalReadingSeconds += alloc.activeSeconds
                    if alloc.activeSeconds >= 60 {
                        activeDaysSet.insert(alloc.date)
                    }
                    let m = calendar.component(.month, from: alloc.date)
                    monthTimeMap[m, default: 0] += alloc.activeSeconds
                    
                    if let bId = session.bookId {
                        bookTimeMap[bId, default: 0] += alloc.activeSeconds
                    }
                }
            }
        }
        
        // Unique books completed during the selected year
        var uniqueCompletedIds = Set<UUID>()
        var completedSummaries: [WrappedBookSummary] = []
        
        for b in books where b.status == ReadingStatus.finished.rawValue {
            let isCompletedInYear: Bool
            if let fDate = b.finishDate {
                isCompletedInYear = (fDate >= yearStart && fDate <= yearEnd)
            } else {
                let hasSessionInYear = completedSessions.contains { s in
                    s.bookId == b.id && s.startedAt >= yearStart && s.startedAt <= yearEnd
                }
                let pagesReached = (b.currentPage ?? 0) >= (b.totalPages ?? 1)
                isCompletedInYear = hasSessionInYear && pagesReached
            }
            
            if isCompletedInYear && !uniqueCompletedIds.contains(b.id) {
                uniqueCompletedIds.insert(b.id)
                completedSummaries.append(
                    WrappedBookSummary(
                        id: b.id,
                        title: b.title,
                        author: b.author,
                        coverColorHex: b.coverColorHex,
                        coverIcon: b.coverIcon,
                        totalActiveSeconds: bookTimeMap[b.id] ?? 0,
                        pagesRead: bookPagesMap[b.id] ?? 0,
                        rating: b.rating,
                        finishDate: b.finishDate
                    )
                )
            }
        }
        
        // Books started during the year
        let booksStartedCount = books.filter { b in
            guard let sDate = b.startDate else { return false }
            return sDate >= yearStart && sDate <= yearEnd
        }.count
        
        // Currently reading
        let currentlyReadingCount = books.filter { $0.status == ReadingStatus.currentlyReading.rawValue }.count
        
        // Most-read book based on recorded session time
        var mostReadBook: WrappedBookSummary? = nil
        if let topEntry = bookTimeMap.max(by: { $0.value < $1.value }), topEntry.value > 0 {
            if let matched = books.first(where: { $0.id == topEntry.key }) {
                mostReadBook = WrappedBookSummary(
                    id: matched.id,
                    title: matched.title,
                    author: matched.author,
                    coverColorHex: matched.coverColorHex,
                    coverIcon: matched.coverIcon,
                    totalActiveSeconds: topEntry.value,
                    pagesRead: bookPagesMap[matched.id] ?? 0,
                    rating: matched.rating,
                    finishDate: matched.finishDate
                )
            }
        }
        
        // Most productive month
        var mostProductiveMonthName: String? = nil
        var mostProductiveMonthSeconds: Int = 0
        if let topMonth = monthTimeMap.max(by: { $0.value < $1.value }), topMonth.value > 0 {
            var comps = DateComponents()
            comps.year = year
            comps.month = topMonth.key
            comps.day = 1
            if let mDate = calendar.date(from: comps) {
                let mFormatter = DateFormatter()
                mFormatter.dateFormat = "LLLL"
                mostProductiveMonthName = mFormatter.string(from: mDate)
                mostProductiveMonthSeconds = topMonth.value
            }
        }
        
        let isEmpty = (totalReadingSeconds == 0 && completedSummaries.isEmpty)
        
        // Factual milestones list
        let milestones = formulateYearlyMilestones(
            completedCount: completedSummaries.count,
            readingDays: activeDaysSet.count,
            totalDaysInYear: totalDaysInYear,
            totalSeconds: totalReadingSeconds,
            booksStarted: booksStartedCount,
            mostProductiveMonth: mostProductiveMonthName,
            mostProductiveSeconds: mostProductiveMonthSeconds
        )
        
        return YearlyWrappedData(
            year: year,
            title: yearTitle,
            totalReadingSeconds: totalReadingSeconds,
            readingDaysCount: activeDaysSet.count,
            totalDaysInYear: totalDaysInYear,
            uniqueBooksCompleted: completedSummaries,
            booksStartedCount: booksStartedCount,
            currentlyReadingCount: currentlyReadingCount,
            mostReadBook: mostReadBook,
            mostProductiveMonthName: mostProductiveMonthName,
            mostProductiveMonthSeconds: mostProductiveMonthSeconds,
            longestSessionSeconds: longestSessionSeconds,
            totalSessionsCount: totalSessionsCount,
            totalPagesRead: totalPagesRead,
            milestones: milestones,
            isEmpty: isEmpty
        )
    }
    
    // MARK: - Honest Highlight Generators
    
    private static func formulateMonthlyHighlight(
        completedCount: Int,
        readingDays: Int,
        totalDays: Int,
        totalSeconds: Int,
        longestSessionSeconds: Int,
        longestBookTitle: String?,
        monthTitle: String
    ) -> String {
        guard totalSeconds > 0 || completedCount > 0 else {
            return "No reading sessions recorded for \(monthTitle)."
        }
        
        if completedCount > 0 && readingDays >= 10 {
            let bookWord = completedCount == 1 ? "book" : "books"
            return "Finished \(completedCount) \(bookWord) while reading across \(readingDays) of \(totalDays) days."
        } else if completedCount > 0 {
            let bookWord = completedCount == 1 ? "book" : "books"
            let durationStr = Formatters.formatDuration(seconds: totalSeconds, style: .short)
            return "Completed \(completedCount) \(bookWord) with \(durationStr) of total reading time."
        } else if readingDays >= 15 {
            let percentage = Int(round(Double(readingDays) / Double(totalDays) * 100))
            return "Exceptional consistency: active reading on \(readingDays) of \(totalDays) days (\(percentage)%)."
        } else if longestSessionSeconds >= 3600, let title = longestBookTitle {
            let longStr = Formatters.formatDuration(seconds: longestSessionSeconds, style: .short)
            return "Deep focus milestone: longest reading session lasted \(longStr) on “\(title)”."
        } else {
            let durationStr = Formatters.formatDuration(seconds: totalSeconds, style: .full)
            return "Dedicated \(durationStr) of focused reading time across \(readingDays) active days."
        }
    }
    
    private static func formulateYearlyMilestones(
        completedCount: Int,
        readingDays: Int,
        totalDaysInYear: Int,
        totalSeconds: Int,
        booksStarted: Int,
        mostProductiveMonth: String?,
        mostProductiveSeconds: Int
    ) -> [String] {
        guard totalSeconds > 0 || completedCount > 0 else {
            return ["No reading history recorded for this year."]
        }
        
        var list: [String] = []
        
        // 1. Completion & Volume
        if completedCount > 0 {
            let bookWord = completedCount == 1 ? "book" : "books"
            list.append("\(completedCount) unique \(bookWord) finished")
        } else if booksStarted > 0 {
            list.append("\(booksStarted) reading journeys started")
        }
        
        if totalSeconds > 0 {
            list.append("\(Formatters.formatDuration(seconds: totalSeconds, style: .full)) of immersion")
        }
        
        // 2. Consistency
        if readingDays > 0 {
            let percentage = Int(round(Double(readingDays) / Double(totalDaysInYear) * 100))
            list.append("\(readingDays) active reading days (\(percentage)% of the year)")
        }
        
        // 3. Peak month
        if let peakMonth = mostProductiveMonth, mostProductiveSeconds > 0 {
            let peakTime = Formatters.formatDuration(seconds: mostProductiveSeconds, style: .short)
            list.append("Peak reading in \(peakMonth) (\(peakTime))")
        }
        
        return list
    }
    
    private static func emptyMonthlyData(month: Int, year: Int) -> MonthlyWrappedData {
        MonthlyWrappedData(
            month: month,
            year: year,
            title: "\(month)/\(year)",
            totalReadingSeconds: 0,
            readingDaysCount: 0,
            totalDaysInMonth: 30,
            longestSessionSeconds: 0,
            longestSessionBookTitle: nil,
            mostReadBook: nil,
            completedBooks: [],
            totalSessionsCount: 0,
            totalPagesRead: 0,
            dataGroundedHighlight: "No reading sessions recorded for this month.",
            isEmpty: true
        )
    }
    
    private static func emptyYearlyData(year: Int) -> YearlyWrappedData {
        YearlyWrappedData(
            year: year,
            title: "\(year) Reading Wrapped",
            totalReadingSeconds: 0,
            readingDaysCount: 0,
            totalDaysInYear: 365,
            uniqueBooksCompleted: [],
            booksStartedCount: 0,
            currentlyReadingCount: 0,
            mostReadBook: nil,
            mostProductiveMonthName: nil,
            mostProductiveMonthSeconds: 0,
            longestSessionSeconds: 0,
            totalSessionsCount: 0,
            totalPagesRead: 0,
            milestones: ["No reading history recorded for \(year)."],
            isEmpty: true
        )
    }
}

