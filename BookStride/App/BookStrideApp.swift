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
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        ReadingTimerService.shared.restoreActiveSession()
                    case .background, .inactive:
                        ReadingTimerService.shared.recalculateElapsed()
                    @unknown default:
                        break
                    }
                }
        }
        .modelContainer(container)
    }
}

