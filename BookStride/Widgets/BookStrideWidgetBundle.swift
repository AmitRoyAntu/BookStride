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
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.1, *) {
            ReadingLiveActivityWidget()
        }
        #endif
    }
}
#endif
#endif

