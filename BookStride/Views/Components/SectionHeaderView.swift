//
//  SectionHeaderView.swift
//  BookStride
//
//  Header component for sections with optional trailing action button.
//

import SwiftUI

public struct SectionHeaderView<ActionContent: View>: View {
    public var title: String
    public var subtitle: String?
    public var action: () -> ActionContent
    
    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder action: @escaping () -> ActionContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.subheadline)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
            }
            
            Spacer()
            
            action()
        }
        .padding(.vertical, 4)
    }
}

public extension SectionHeaderView where ActionContent == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

