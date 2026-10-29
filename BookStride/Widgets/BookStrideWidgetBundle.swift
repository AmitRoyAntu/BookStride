//
//  BookStrideWidgetBundle.swift
//  BookStride
//
//  WidgetKit bundle entry point for the Bookstride Widget extension.
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit

#if WIDGET_EXTENSION
@main
struct BookStrideWidgetBundle: WidgetBundle {
    var body: some Widget {
        BookStrideTimerWidget()
    }
}
#endif
#endif

