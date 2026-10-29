//
//  BookStrideWidgetIntents.swift
//  BookStride
//
//  App Intents providing interactive controls for the Bookstride Reading Timer widget.
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
    public static var description = IntentDescription("Pause or resume the active Bookstride reading timer.")
    
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
#endif

