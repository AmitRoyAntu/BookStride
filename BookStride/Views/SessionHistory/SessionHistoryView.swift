//
//  SessionHistoryView.swift
//  BookStride
//
//  Detailed history of all completed reading sessions with grouping and editing.
//

import SwiftUI
import SwiftData

public struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingSession.startedAt, order: .reverse)
    private var allSessions: [ReadingSession]
    
    @State private var showingAddSessionSheet: Bool = false
    @State private var searchText: String = ""
    
    public init() {}
    
    private var completedSessions: [ReadingSession] {
        allSessions.filter { $0.status == .completed }
    }
    
    private var filteredSessions: [ReadingSession] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return completedSessions
        }
        return completedSessions.filter { s in
            (s.book?.title.lowercased().contains(query) ?? false) ||
            (s.notes?.lowercased().contains(query) ?? false)
        }
    }
    
    // Group sessions by day
    private var groupedSessions: [(date: Date, sessions: [ReadingSession])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredSessions) { s in
            cal.startOfDay(for: s.startedAt)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, sessions: $0.value) }
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if completedSessions.isEmpty {
                    VStack {
                        Spacer(minLength: 40)
                        EmptyStateCard(
                            iconName: "clock.arrow.circlepath",
                            title: "No Sessions Logged",
                            message: "Start a reading session or log past reading to see your history here.",
                            buttonTitle: "Log a Session",
                            action: { showingAddSessionSheet = true }
                        )
                        .padding(.horizontal, 24)
                        Spacer(minLength: 40)
                    }
                } else if filteredSessions.isEmpty {
                    EmptyStateCard(
                        iconName: "magnifyingglass",
                        title: "No Matching Sessions",
                        message: "No sessions matched \"\(searchText)\"."
                    )
                    .padding(.horizontal, 24)
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(groupedSessions, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(Formatters.formatDate(group.date, style: .relative))
                                        .font(.system(.headline, design: .serif, weight: .bold))
                                        .foregroundColor(BookStrideTheme.deepCharcoal)
                                    
                                    Spacer()
                                    
                                    let totalDaySeconds = group.sessions.reduce(0) { $0 + $1.activeDurationSeconds }
                                    Text(Formatters.formatDuration(seconds: totalDaySeconds, style: .short))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(BookStrideTheme.forestGreen)
                                }
                                .padding(.horizontal, 4)
                                
                                ForEach(group.sessions) { session in
                                    SessionRowView(session: session)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 20)
        }
        .BookStrideBackground()
        .navigationTitle("Reading History")
        .searchable(text: $searchText, prompt: "Search by book title or note")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSessionSheet = true
                } label: {
                    Label("Log Session", systemImage: "plus")
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
        }
        .sheet(isPresented: $showingAddSessionSheet) {
            ManualSessionSheet()
        }
    }
}

