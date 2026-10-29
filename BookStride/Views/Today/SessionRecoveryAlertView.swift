//
//  SessionRecoveryAlertView.swift
//  BookStride
//
//  Alert and recovery sheet for sessions left unmonitored after app relaunch.
//

import SwiftUI

public struct SessionRecoveryAlertView: View {
    @ObservedObject var timerService: ReadingTimerService
    @State private var customMinutes: Int = 30
    
    public init(timerService: ReadingTimerService) {
        self.timerService = timerService
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(BookStrideTheme.streakAmber)
                .padding(.top, 12)
            
            Text("Review Unmonitored Session")
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundColor(BookStrideTheme.deepCharcoal)
            
            Text("Your reading session was active when BookStride was closed. Since \(Formatters.formatDuration(seconds: timerService.unmonitoredElapsedSeconds, style: .full)) elapsed, how would you like to record this reading time?")
                .font(.body)
                .foregroundColor(BookStrideTheme.mutedSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button {
                    timerService.resolveStaleSession(action: .keepCapped(seconds: 3600))
                } label: {
                    HStack {
                        Image(systemName: "hourglass")
                        Text("Record 1 Hour (Standard Reading)")
                        Spacer()
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .padding()
                    .BookStrideCardStyle()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Custom duration: \(customMinutes) minutes")
                            .font(.callout.weight(.medium))
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                        Spacer()
                    }
                    Stepper("Duration", value: $customMinutes, in: 5...240, step: 5)
                    
                    Button {
                        timerService.resolveStaleSession(action: .customDuration, customMinutes: customMinutes)
                    } label: {
                        Text("Save \(customMinutes) Minutes")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(BookStrideTheme.forestGreen)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .BookStrideCardStyle()
                
                Button(role: .destructive) {
                    timerService.resolveStaleSession(action: .discard)
                } label: {
                    Text("Discard This Session")
                        .font(.callout)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}

