//
//  SampleDataService.swift
//  BookStride
//
//  Explicit opt-in sample data generator for evaluation and screenshots.
//

import Foundation
import SwiftData

public enum SampleDataService {
    
    @MainActor
    public static func populateSampleData(in context: ModelContext) {
        let cal = Calendar.current
        let today = Date()
        
        // 1. Create Books
        let klara = Book(
            title: "Klara and the Sun",
            author: "Kazuo Ishiguro",
            coverColorHex: "gold",
            coverIcon: "sun.max",
            totalPages: 303,
            currentPage: 215,
            status: .currentlyReading,
            startDate: cal.date(byAdding: .day, value: -14, to: today),
            rating: 5,
            bookDescription: "A poignant exploration of what it means to love through the eyes of an Artificial Friend."
        )
        
        let atomic = Book(
            title: "Atomic Habits",
            author: "James Clear",
            coverColorHex: "terracotta",
            coverIcon: "bolt.fill",
            totalPages: 320,
            currentPage: 320,
            status: .finished,
            startDate: cal.date(byAdding: .day, value: -35, to: today),
            finishDate: cal.date(byAdding: .day, value: -8, to: today),
            rating: 5,
            bookDescription: "An easy and proven way to build good habits and break bad ones."
        )
        
        let moscow = Book(
            title: "A Gentleman in Moscow",
            author: "Amor Towles",
            coverColorHex: "burgundy",
            coverIcon: "crown.fill",
            totalPages: 462,
            currentPage: 98,
            status: .currentlyReading,
            startDate: cal.date(byAdding: .day, value: -5, to: today),
            rating: 4,
            bookDescription: "In 1922, a thirty-year-old Russian aristocrat is sentenced to spend the rest of his life inside a luxury hotel."
        )
        
        let dune = Book(
            title: "Dune",
            author: "Frank Herbert",
            coverColorHex: "forest",
            coverIcon: "mountain.2.fill",
            totalPages: 688,
            currentPage: 0,
            status: .wantToRead,
            startDate: nil,
            bookDescription: "Set on the desert planet Arrakis, Dune is the story of the boy Paul Atreides."
        )
        
        context.insert(klara)
        context.insert(atomic)
        context.insert(moscow)
        context.insert(dune)
        
        // 2. Add realistic reading sessions to demonstrate streaks and charts
        // Consecutive days reaching the 30-min goal over the last 6 days + today
        let sessionPlans: [(daysAgo: Int, minutes: Int, book: Book, startP: Int, endP: Int)] = [
            (daysAgo: 6, minutes: 35, book: atomic, startP: 240, endP: 265),
            (daysAgo: 5, minutes: 42, book: atomic, startP: 265, endP: 295),
            (daysAgo: 4, minutes: 30, book: atomic, startP: 295, endP: 320),
            (daysAgo: 3, minutes: 45, book: klara, startP: 110, endP: 145),
            (daysAgo: 2, minutes: 35, book: klara, startP: 145, endP: 175),
            (daysAgo: 1, minutes: 40, book: moscow, startP: 45, endP: 72),
            (daysAgo: 0, minutes: 32, book: klara, startP: 175, endP: 200)
        ]
        
        for plan in sessionPlans {
            guard let sessionDate = cal.date(byAdding: .day, value: -plan.daysAgo, to: today) else { continue }
            let start = cal.date(bySettingHour: 20, minute: 15, second: 0, of: sessionDate) ?? sessionDate
            let activeSec = plan.minutes * 60
            let end = start.addingTimeInterval(Double(activeSec))
            
            let session = ReadingSession(
                book: plan.book,
                startedAt: start,
                endedAt: end,
                status: .completed,
                accumulatedActiveSeconds: activeSec,
                lastResumedAt: nil,
                lastPausedAt: nil,
                pausedDurationSeconds: 0,
                startPage: plan.startP,
                endPage: plan.endP,
                notes: plan.daysAgo == 0 ? "Wonderful chapter on memory." : nil
            )
            context.insert(session)
        }
        
        // 3. Add Journal entries (Notes & Quotes)
        let quote1 = JournalEntry(
            book: klara,
            content: "Do you believe in the human heart? I don’t mean simply the organ, obviously. But do you think there’s something that makes each of us special and individual?",
            entryType: .quote,
            pageNumber: 134,
            isFavorite: true,
            createdAt: cal.date(byAdding: .day, value: -3, to: today) ?? today
        )
        
        let quote2 = JournalEntry(
            book: atomic,
            content: "You do not rise to the level of your goals. You fall to the level of your systems.",
            entryType: .quote,
            pageNumber: 27,
            isFavorite: true,
            createdAt: cal.date(byAdding: .day, value: -12, to: today) ?? today
        )
        
        let note1 = JournalEntry(
            book: moscow,
            content: "The count's perspective on circumstance versus character is remarkably stoic and charming.",
            entryType: .note,
            pageNumber: 62,
            isFavorite: false,
            createdAt: cal.date(byAdding: .day, value: -1, to: today) ?? today
        )
        
        context.insert(quote1)
        context.insert(quote2)
        context.insert(note1)
        
        // Save changes
        try? context.save()
    }
    
    @MainActor
    public static func clearAllData(in context: ModelContext) {
        do {
            try context.delete(model: ReadingSession.self)
            try context.delete(model: JournalEntry.self)
            try context.delete(model: Book.self)
            try context.save()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }
}

