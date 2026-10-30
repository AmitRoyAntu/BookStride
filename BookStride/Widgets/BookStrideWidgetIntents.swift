//
//  BookStrideWidgetIntents.swift
//  BookStride
//
//  App Intents providing interactive controls for the BookStride Reading Timer widget.
//

import Foundation
#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

#if canImport(AppIntents)
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct ToggleReadingTimerIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle Reading Timer"
    public static var description = IntentDescription("Pause or resume the active BookStride reading timer.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        // Safely toggle reading timer state using shared AppGroup defaults
        ReadingTimerService.shared.toggleTimerFromWidget()
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        return .result()
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct FinishReadingActivityIntent: AppIntent {
    public static var title: LocalizedStringResource = "Finish Reading Session"
    public static var description = IntentDescription("Finish the active reading session in BookStride.")
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        ReadingTimerService.shared.finishSessionFromWidget()
        
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        return .result()
    }
}
#endif

