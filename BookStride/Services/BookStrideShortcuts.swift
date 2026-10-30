//
//  BookStrideShortcuts.swift
//  BookStride
//
//  App Intents and AppShortcutsProvider for Siri and Apple Shortcuts integration.
//

import Foundation
#if canImport(AppIntents)
import AppIntents
#endif

#if canImport(AppIntents)
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct StartReadingSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Reading Session"
    public static var description = IntentDescription("Starts a reading session in BookStride.")
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Book")
    public var book: BookEntity?
    
    public init() {}
    
    public init(book: BookEntity?) {
        self.book = book
    }
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let timerService = ReadingTimerService.shared
        
        let title = book?.title ?? "Untitled Book"
        let bookId = book?.id
        let startPage = book?.currentPage
        
        if timerService.isRunning || timerService.isPaused {
            return .result(dialog: "A reading session is already active in BookStride.")
        }
        
        let started = timerService.startSession(
            bookId: bookId,
            bookTitle: title,
            startPage: startPage
        )
        
        if started {
            if let bookTitle = book?.title {
                return .result(dialog: "Started reading \"\(bookTitle)\" in BookStride.")
            } else {
                return .result(dialog: "Started a reading session in BookStride.")
            }
        } else {
            return .result(dialog: "Could not start reading session.")
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct PauseReadingSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Pause Reading Session"
    public static var description = IntentDescription("Pauses the currently active reading session in BookStride.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let timerService = ReadingTimerService.shared
        timerService.restoreActiveSession()
        
        guard let state = timerService.activeState else {
            return .result(dialog: "There is no active reading session to pause.")
        }
        
        if state.isPaused {
            return .result(dialog: "Your reading session is already paused.")
        }
        
        timerService.pauseSession()
        return .result(dialog: "Paused your reading session in BookStride.")
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct ResumeReadingSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Resume Reading Session"
    public static var description = IntentDescription("Resumes a paused reading session in BookStride.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let timerService = ReadingTimerService.shared
        timerService.restoreActiveSession()
        
        guard let state = timerService.activeState else {
            return .result(dialog: "There is no active reading session to resume.")
        }
        
        if !state.isPaused {
            return .result(dialog: "Your reading session is already running.")
        }
        
        timerService.resumeSession()
        return .result(dialog: "Resumed your reading session in BookStride.")
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct FinishReadingSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Finish Reading Session"
    public static var description = IntentDescription("Finishes the active reading session and logs your reading time.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let timerService = ReadingTimerService.shared
        timerService.restoreActiveSession()
        
        guard let snapshot = timerService.finishSession() else {
            return .result(dialog: "There is no active reading session to finish.")
        }
        
        let minutes = max(1, snapshot.accumulatedActiveSeconds / 60)
        return .result(dialog: "Finished reading session in BookStride. You read for \(minutes) minutes.")
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct GetTodayReadingDurationIntent: AppIntent {
    public static var title: LocalizedStringResource = "Get Today's Reading Duration"
    public static var description = IntentDescription("Returns total minutes read today in BookStride.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let defaults = AppGroupConfig.sharedDefaults
        var todaySecs = 0
        
        if let data = defaults.data(forKey: AppGroupConfig.todayProgressKey),
           let snapshot = try? JSONDecoder().decode(TodayProgressSnapshot.self, from: data) {
            todaySecs = snapshot.todaySeconds
        }
        
        // Add active session elapsed seconds if currently reading today
        ReadingTimerService.shared.restoreActiveSession()
        if let state = ReadingTimerService.shared.activeState, !state.isPaused {
            todaySecs += state.accumulatedActiveSeconds
        }
        
        let minutes = todaySecs / 60
        let formatted = Formatters.formatDuration(seconds: todaySecs, style: .short)
        
        return .result(
            value: minutes,
            dialog: "You have read for \(formatted) today in BookStride."
        )
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct UpdateBookProgressIntent: AppIntent {
    public static var title: LocalizedStringResource = "Update Book Progress"
    public static var description = IntentDescription("Updates the current page number for a book in BookStride.")
    
    @Parameter(title: "Book")
    public var book: BookEntity
    
    @Parameter(title: "Current Page")
    public var pageNumber: Int
    
    public init() {}
    
    public init(book: BookEntity, pageNumber: Int) {
        self.book = book
        self.pageNumber = pageNumber
    }
    
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard pageNumber >= 0 else {
            return .result(dialog: "Page number cannot be negative.")
        }
        
        if let total = book.totalPages, pageNumber > total {
            return .result(dialog: "Page \(pageNumber) cannot exceed total pages of \(total) in \"\(book.title)\".")
        }
        
        BookCacheService.updateCachedBookPage(bookId: book.id, newPage: pageNumber)
        
        return .result(dialog: "Updated progress for \"\(book.title)\" to page \(pageNumber).")
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct BookStrideShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartReadingSessionIntent(),
            phrases: [
                "Start reading in \(.applicationName)",
                "Start a reading session in \(.applicationName)",
                "Begin reading in \(.applicationName)"
            ],
            shortTitle: "Start Reading",
            systemImageName: "book.fill"
        )
        
        AppShortcut(
            intent: PauseReadingSessionIntent(),
            phrases: [
                "Pause reading in \(.applicationName)",
                "Pause reading session in \(.applicationName)"
            ],
            shortTitle: "Pause Reading",
            systemImageName: "pause.fill"
        )
        
        AppShortcut(
            intent: ResumeReadingSessionIntent(),
            phrases: [
                "Resume reading in \(.applicationName)",
                "Resume reading session in \(.applicationName)"
            ],
            shortTitle: "Resume Reading",
            systemImageName: "play.fill"
        )
        
        AppShortcut(
            intent: FinishReadingSessionIntent(),
            phrases: [
                "Finish reading in \(.applicationName)",
                "Finish reading session in \(.applicationName)",
                "End reading session in \(.applicationName)"
            ],
            shortTitle: "Finish Reading",
            systemImageName: "checkmark.circle.fill"
        )
        
        AppShortcut(
            intent: GetTodayReadingDurationIntent(),
            phrases: [
                "How much have I read today in \(.applicationName)",
                "Check reading time in \(.applicationName)",
                "Show today's reading in \(.applicationName)"
            ],
            shortTitle: "Today's Reading Time",
            systemImageName: "clock.fill"
        )
    }
}
#endif
