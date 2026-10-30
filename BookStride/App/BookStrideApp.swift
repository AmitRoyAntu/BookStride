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
                    case .background, .inactive:
                        ReadingTimerService.shared.recalculateElapsed()
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
        guard url.scheme == "bookstride" else { return }
        switch url.host {
        case "timer", "session":
            ReadingTimerService.shared.shouldOpenTimerModal = true
        case "start":
            ReadingTimerService.shared.shouldTriggerBookPicker = true
        default:
            ReadingTimerService.shared.shouldOpenTimerModal = true
        }
    }
}

