//
//  AppNavigationSplitView.swift
//  BookStride
//
//  Adaptive NavigationSplitView designed for iPadOS responsive multitasking and full screen.
//

import SwiftUI

public enum NavigationSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case library = "Library"
    case insights = "Insights"
    case journal = "Journal"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .today: return "sun.max"
        case .library: return "books.vertical"
        case .insights: return "chart.bar.xaxis"
        case .journal: return "quote.opening"
        case .settings: return "gearshape"
        }
    }
}

public struct AppNavigationSplitView: View {
    @State private var selectedSection: NavigationSection? = .today
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            List(selection: $selectedSection) {
                // Bookstride App Branding Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.pages")
                            .font(.title2)
                            .foregroundColor(BookStrideTheme.forestGreen)
                        
                        Text("Bookstride")
                            .font(.system(.title2, design: .serif, weight: .bold))
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                    }
                    
                    Text("Reading Tracker & Journal")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                .padding(.vertical, 8)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                Section {
                    ForEach(NavigationSection.allCases) { section in
                        NavigationLink(value: section) {
                            Label {
                                Text(section.rawValue)
                                    .font(.headline)
                                    .foregroundColor(BookStrideTheme.deepCharcoal)
                            } icon: {
                                Image(systemName: section.iconName)
                                    .foregroundColor(selectedSection == section ? BookStrideTheme.forestGreen : BookStrideTheme.mutedSlate)
                            }
                        }
                        .listRowBackground(
                            selectedSection == section
                            ? BookStrideTheme.forestGreen.opacity(0.12)
                            : Color.clear
                        )
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Bookstride")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            .navigationDestination(for: NavigationSection.self) { section in
                detailContent(for: section)
            }
        } detail: {
            // Detail / Main Content Area
            NavigationStack {
                detailContent(for: selectedSection ?? .today)
            }
        }
        .tint(BookStrideTheme.forestGreen)
    }
    
    @ViewBuilder
    private func detailContent(for section: NavigationSection) -> some View {
        switch section {
        case .today:
            TodayDashboardView()
        case .library:
            LibraryView()
        case .insights:
            InsightsView()
        case .journal:
            JournalView()
        case .settings:
            SettingsView()
        }
    }
}

