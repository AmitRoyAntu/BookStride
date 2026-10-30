//
//  BookStrideWidgetBundle.swift
//  BookStride
//
//  WidgetKit bundle entry point for the BookStride Widget extension.
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit

#if WIDGET_EXTENSION
@main
struct BookStrideWidgetBundle: WidgetBundle {
    var body: some Widget {
        BookStrideTimerWidget()
        #if canImport(ActivityKit)
        if #available(iOS 16.1, macOS 13.0, *) {
            ReadingLiveActivityWidget()
        }
        #endif
    }
}
#endif
#endif

