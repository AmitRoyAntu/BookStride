//
//  BookStrideApp.swift
//  BookStride
//
//  Application entry point and SwiftData schema container initialization.
//

import SwiftUI
import SwiftData

@main
struct BookStrideApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                Book.self,
                ReadingSession.self,
                ReadingGoal.self,
                JournalEntry.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AppNavigationSplitView()
                .BookStrideBackground()
                #if os(macOS)
                .frame(minWidth: 960, minHeight: 640)
                #endif
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        ReadingTimerService.shared.restoreActiveSession()
                        IncomingShareProcessor.processPendingShares(modelContext: container.mainContext)
                        performAutoBackup()
                    case .background, .inactive:
                        ReadingTimerService.shared.recalculateElapsed()
                        if newPhase == .background {
                            performAutoBackup()
                        }
                    @unknown default:
                        break
                    }
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(container)
        .commands {
            SidebarCommands()
            CommandMenu("Reading Timer") {
                Button("Start Reading Session...") {
                    if ReadingTimerService.shared.activeState == nil {
                        ReadingTimerService.shared.shouldTriggerBookPicker = true
                    } else {
                        ReadingTimerService.shared.shouldOpenTimerModal = true
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Button("Pause / Resume Session") {
                    if ReadingTimerService.shared.isPaused {
                        ReadingTimerService.shared.resumeSession()
                    } else if ReadingTimerService.shared.isRunning {
                        ReadingTimerService.shared.pauseSession()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command])
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        IncomingShareProcessor.processPendingShares(modelContext: container.mainContext)
        IncomingShareProcessor.processDirectURL(url, in: container.mainContext)
        guard url.scheme == "bookstride" else { return }
        switch url.host {
        case "timer", "session":
            ReadingTimerService.shared.shouldOpenTimerModal = true
        case "start":
            ReadingTimerService.shared.shouldTriggerBookPicker = true
        case "incoming":
            // Direct share handoff received and processed into SwiftData
            break
        default:
            ReadingTimerService.shared.shouldOpenTimerModal = true
        }
    }
    
    @MainActor
    private func performAutoBackup() {
        let context = container.mainContext
        do {
            let books = try context.fetch(FetchDescriptor<Book>())
            guard !books.isEmpty else { return }
            let sessions = try context.fetch(FetchDescriptor<ReadingSession>())
            let goals = try context.fetch(FetchDescriptor<ReadingGoal>())
            let journal = try context.fetch(FetchDescriptor<JournalEntry>())
            
            let bookDTOs = books.map { b in
                BookDTO(
                    id: b.id,
                    title: b.title,
                    author: b.author,
                    coverColorHex: b.coverColorHex,
                    coverIcon: b.coverIcon,
                    totalPages: b.totalPages,
                    currentPage: b.currentPage,
                    status: b.statusRawValue,
                    startDate: b.startDate,
                    finishDate: b.finishDate,
                    rating: b.rating,
                    bookDescription: b.bookDescription,
                    appleBooksURL: b.appleBooksURL,
                    importedFileName: b.importedFileName,
                    sourceFormat: b.sourceFormatRawValue,
                    createdAt: b.createdAt,
                    updatedAt: b.updatedAt
                )
            }
            
            let sessionDTOs = sessions.map { s in
                ReadingSessionDTO(
                    id: s.id,
                    bookId: s.book?.id,
                    startedAt: s.startedAt,
                    endedAt: s.endedAt,
                    status: s.statusRawValue,
                    accumulatedActiveSeconds: s.accumulatedActiveSeconds,
                    pausedDurationSeconds: s.pausedDurationSeconds,
                    startPage: s.startPage,
                    endPage: s.endPage,
                    notes: s.notes,
                    createdAt: s.createdAt,
                    updatedAt: s.updatedAt
                )
            }
            
            let goalDTO: ReadingGoalDTO
            if let activeG = goals.first {
                goalDTO = ReadingGoalDTO(
                    dailyMinutes: activeG.dailyMinutes,
                    dailyPages: activeG.dailyPages,
                    yearlyBookTarget: activeG.yearlyBookTarget
                )
            } else {
                goalDTO = ReadingGoalDTO(dailyMinutes: 20, dailyPages: nil, yearlyBookTarget: nil)
            }
            
            let journalDTOs = journal.map { j in
                JournalEntryDTO(
                    id: j.id,
                    bookId: j.book?.id,
                    content: j.content,
                    entryType: j.entryTypeRawValue,
                    pageNumber: j.pageNumber,
                    isFavorite: j.isFavorite,
                    createdAt: j.createdAt,
                    updatedAt: j.updatedAt
                )
            }
            
            let package = BookStrideBackupPackage(
                schemaVersion: DataExportService.currentSchemaVersion,
                appVersion: "1.0.0",
                exportedAt: Date(),
                books: bookDTOs,
                sessions: sessionDTOs,
                goals: goalDTO,
                journalEntries: journalDTOs
            )
            
            DataExportService.performAutomaticLocalBackup(package: package)
        } catch {
            print("Auto backup encountered error: \(error.localizedDescription)")
        }
    }
}

