//
//  EmptyStateCard.swift
//  BookStride
//
//  Consistent minimalist empty state illustration for iPad screens.
//

import SwiftUI

public struct EmptyStateCard: View {
    public var iconName: String
    public var title: String
    public var message: String
    public var buttonTitle: String?
    public var action: (() -> Void)?
    
    public init(
        iconName: String,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.iconName = iconName
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(BookStrideTheme.forestGreen.opacity(0.85))
                .padding(.bottom, 4)
            
            Text(title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundColor(BookStrideTheme.deepCharcoal)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(BookStrideTheme.mutedSlate)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            
            if let bTitle = buttonTitle, let act = action {
                Button(action: act) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text(bTitle)
                    }
                    .font(.callout.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(BookStrideTheme.forestGreen)
                    .cornerRadius(20)
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .BookStrideCardStyle()
    }
}

