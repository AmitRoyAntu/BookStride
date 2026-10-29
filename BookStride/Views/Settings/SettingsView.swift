//
//  SettingsView.swift
//  BookStride
//
//  Application settings, reading goals, notification habits, data export/import, and about BookStride.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var notificationService = NotificationService.shared
    
    @Query private var goals: [ReadingGoal]
    @Query private var allBooks: [Book]
    @Query private var allSessions: [ReadingSession]
    @Query private var allJournalEntries: [JournalEntry]
    
    // Goals state
    @State private var dailyMinutes: Int = 30
    @State private var dailyPages: Int = 20
    @State private var hasDailyPagesGoal: Bool = false
    @State private var yearlyBooks: Int = 25
    @State private var hasYearlyBooksGoal: Bool = true
    
    // Display Preferences
    @AppStorage("BookStride_preferred_duration_style") private var preferredDurationStyle: String = "full"
    
    // Notifications state
    @State private var enableDailyReminder: Bool = false
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showingPermissionDeniedAlert: Bool = false
    
    // Backup & Export
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet: Bool = false
    @State private var showingFileImporter: Bool = false
    @State private var importErrorMessage: String?
    @State private var importSuccessMessage: String?
    @State private var showingAlert: Bool = false
    
    // Demo data
    @State private var showingClearConfirmation: Bool = false
    @State private var showingSampleDataPopulatedNotice: Bool = false
    
    public init() {}
    
    private var activeGoal: ReadingGoal {
        if let first = goals.first {
            return first
        } else {
            let g = ReadingGoal()
            modelContext.insert(g)
            try? modelContext.save()
            return g
        }
    }
    
    public var body: some View {
        Form {
            // Section 1: Reading Goals
            Section(header: Text("Reading Goals")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Daily Reading Time Goal")
                        Spacer()
                        Text("\(dailyMinutes) minutes")
                            .font(.headline)
                            .foregroundColor(BookStrideTheme.forestGreen)
                    }
                    Stepper("Daily minutes", value: $dailyMinutes, in: 5...300, step: 5)
                        .onChange(of: dailyMinutes) { _, newVal in
                            saveGoals()
                        }
                }
                
                Toggle("Daily Pages Goal", isOn: $hasDailyPagesGoal)
                    .onChange(of: hasDailyPagesGoal) { _, _ in saveGoals() }
                if hasDailyPagesGoal {
                    Stepper("Target: \(dailyPages) pages", value: $dailyPages, in: 5...200, step: 5)
                        .onChange(of: dailyPages) { _, _ in saveGoals() }
                }
                
                Toggle("Yearly Book Target", isOn: $hasYearlyBooksGoal)
                    .onChange(of: hasYearlyBooksGoal) { _, _ in saveGoals() }
                if hasYearlyBooksGoal {
                    Stepper("Target: \(yearlyBooks) books / year", value: $yearlyBooks, in: 1...100, step: 1)
                        .onChange(of: yearlyBooks) { _, _ in saveGoals() }
                }
            }
            
            // Section 2: Display Preferences
            Section(header: Text("Preferred Time Display")) {
                Picker("Time Format", selection: $preferredDurationStyle) {
                    Text("Full Units (1 hr 25 mins)").tag("full")
                    Text("Short Units (1h 25m)").tag("short")
                    Text("Compact Decimals (1.4 hrs)").tag("compact")
                }
                .pickerStyle(.menu)
            }
            
            // Section 3: Streak Rule Explanation
            Section(header: Text("How Streaks Work")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Transparent Habit Counting", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    
                    Text("• A calendar day qualifies for your streak once your active reading reaches your daily goal (\(dailyMinutes) min).\n• While today is underway, an active streak from yesterday is never prematurely broken.\n• Paused intervals are strictly excluded from reading time.\n• Sessions that cross midnight are apportioned to each day's local calendar total.")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }
            
            // Section 3: Daily Reading Reminders
            Section(header: Text("Notifications & Habit Reminders")) {
                Toggle("Daily Reading Reminder", isOn: $enableDailyReminder)
                    .onChange(of: enableDailyReminder) { _, isEnabled in
                        handleReminderToggle(isEnabled)
                    }
                
                if enableDailyReminder {
                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderTime) { _, newTime in
                            scheduleReminder(at: newTime)
                        }
                }
                
                HStack {
                    Text("Permission Status:")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                    Spacer()
                    Text(notificationService.isAuthorized ? "Authorized" : "Not Enabled")
                        .font(.caption.weight(.medium))
                        .foregroundColor(notificationService.isAuthorized ? BookStrideTheme.forestGreen : BookStrideTheme.mutedSlate)
                }
            }
            
            // Section 4: Data Management (Export & Import)
            Section(header: Text("Data Management & Backup")) {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Backup (JSON)")
                        Spacer()
                    }
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                }
                
                Button {
                    showingFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Backup (JSON)")
                        Spacer()
                    }
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                }
                
                HStack {
                    Text("Offline-first:")
                    Spacer()
                    Text("All data is stored locally on this iPad")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
            }
            
            // Section 5: Evaluation & Demo Data
            Section(header: Text("Evaluation & Demo Data")) {
                Button {
                    SampleDataService.populateSampleData(in: modelContext)
                    showingSampleDataPopulatedNotice = true
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Populate Realistic Sample Data")
                        Spacer()
                    }
                    .foregroundColor(BookStrideTheme.forestGreen)
                }
                
                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Data")
                        Spacer()
                    }
                    .foregroundColor(.red)
                }
            }
            
            // Section 6: About Bookstride
            Section(header: Text("About Bookstride")) {
                HStack {
                    Text("App Name")
                    Spacer()
                    Text("Bookstride")
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                HStack {
                    Text("Tagline")
                    Spacer()
                    Text("Your reading journey, one day at a time.")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                HStack {
                    Text("Descriptor")
                    Spacer()
                    Text("Reading Tracker & Journal")
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0 (iPadOS Native)")
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                HStack {
                    Text("Companion App")
                    Spacer()
                    Text("Designed for Apple Books")
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
            }
        }
        .BookStrideBackground()
        .navigationTitle("Settings")
        .onAppear {
            loadGoalValues()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .confirmationDialog("Clear All App Data?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                SampleDataService.clearAllData(in: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all books, reading sessions, and journal entries. This cannot be undone.")
        }
        .alert(importErrorMessage != nil ? "Import Failed" : "Data Management", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? importSuccessMessage ?? "")
        }
        .alert("Sample Data Added", isPresented: $showingSampleDataPopulatedNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sample books, reading sessions spanning streaks, and journal notes have been loaded.")
        }
        .alert("Notification Permission Denied", isPresented: $showingPermissionDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enable notifications for BookStride in iPadOS Settings to receive daily reading reminders.")
        }
    }
    
    // MARK: - Handlers
    
    private func loadGoalValues() {
        let g = activeGoal
        dailyMinutes = g.dailyMinutes
        if let dp = g.dailyPages {
            dailyPages = dp
            hasDailyPagesGoal = true
        } else {
            hasDailyPagesGoal = false
        }
        if let yb = g.yearlyBookTarget {
            yearlyBooks = yb
            hasYearlyBooksGoal = true
        } else {
            hasYearlyBooksGoal = false
        }
    }
    
    private func saveGoals() {
        let g = activeGoal
        g.dailyMinutes = dailyMinutes
        g.dailyPages = hasDailyPagesGoal ? dailyPages : nil
        g.yearlyBookTarget = hasYearlyBooksGoal ? yearlyBooks : nil
        g.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func handleReminderToggle(_ isEnabled: Bool) {
        if isEnabled {
            Task {
                let granted = await notificationService.requestAuthorization()
                if granted {
                    scheduleReminder(at: reminderTime)
                } else {
                    await MainActor.run {
                        enableDailyReminder = false
                        showingPermissionDeniedAlert = true
                    }
                }
            }
        } else {
            notificationService.cancelDailyReminder()
        }
    }
    
    private func scheduleReminder(at date: Date) {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        notificationService.scheduleDailyReminder(hour: hour, minute: minute)
    }
    
    private func exportData() {
        let bookDTOs = allBooks.map { b in
            BookDTO(
                id: b.id,
                title: b.title,
                author: b.author,
                coverColorHex: b.coverColorHex,
                coverIcon: b.coverIcon,
                totalPages: b.totalPages,
                currentPage: b.currentPage,
                status: b.statusRawValue,
                startDate: b.startDate,
                finishDate: b.finishDate,
                rating: b.rating,
                bookDescription: b.bookDescription,
                createdAt: b.createdAt,
                updatedAt: b.updatedAt
            )
        }
        
        let sessionDTOs = allSessions.map { s in
            ReadingSessionDTO(
                id: s.id,
                bookId: s.book?.id,
                startedAt: s.startedAt,
                endedAt: s.endedAt,
                status: s.statusRawValue,
                accumulatedActiveSeconds: s.accumulatedActiveSeconds,
                pausedDurationSeconds: s.pausedDurationSeconds,
                startPage: s.startPage,
                endPage: s.endPage,
                notes: s.notes,
                createdAt: s.createdAt,
                updatedAt: s.updatedAt
            )
        }
        
        let journalDTOs = allJournalEntries.map { j in
            JournalEntryDTO(
                id: j.id,
                bookId: j.book?.id,
                content: j.content,
                entryType: j.entryTypeRawValue,
                pageNumber: j.pageNumber,
                isFavorite: j.isFavorite,
                createdAt: j.createdAt,
                updatedAt: j.updatedAt
            )
        }
        
        let goalDTO = ReadingGoalDTO(
            dailyMinutes: dailyMinutes,
            dailyPages: hasDailyPagesGoal ? dailyPages : nil,
            yearlyBookTarget: hasYearlyBooksGoal ? yearlyBooks : nil
        )
        
        let package = BookStrideBackupPackage(
            schemaVersion: DataExportService.currentSchemaVersion,
            appVersion: "1.0.0",
            exportedAt: Date(),
            books: bookDTOs,
            sessions: sessionDTOs,
            goals: goalDTO,
            journalEntries: journalDTOs
        )
        
        do {
            let fileURL = try DataExportService.writeToTemporaryExportFile(package)
            self.exportedFileURL = fileURL
            self.showingShareSheet = true
        } catch {
            importErrorMessage = "Failed to export backup: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Access to file was denied by iPadOS security."
                showingAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let package = try DataExportService.parseAndValidateJSON(data)
                
                // Import into SwiftData with duplicate avoidance
                var bookMap: [UUID: Book] = [:]
                let existingBooks = try modelContext.fetch(FetchDescriptor<Book>())
                for b in existingBooks {
                    bookMap[b.id] = b
                }
                
                for bDTO in package.books {
                    if let existing = bookMap[bDTO.id] {
                        existing.title = bDTO.title
                        existing.author = bDTO.author
                        existing.coverColorHex = bDTO.coverColorHex
                        existing.coverIcon = bDTO.coverIcon
                        existing.totalPages = bDTO.totalPages
                        existing.currentPage = bDTO.currentPage
                        existing.statusRawValue = bDTO.status
                        existing.startDate = bDTO.startDate
                        existing.finishDate = bDTO.finishDate
                        existing.rating = bDTO.rating
                        existing.bookDescription = bDTO.bookDescription
                    } else {
                        let newBook = Book(
                            id: bDTO.id,
                            title: bDTO.title,
                            author: bDTO.author,
                            coverColorHex: bDTO.coverColorHex,
                            coverIcon: bDTO.coverIcon,
                            totalPages: bDTO.totalPages,
                            currentPage: bDTO.currentPage,
                            status: ReadingStatus(rawValue: bDTO.status) ?? .currentlyReading,
                            startDate: bDTO.startDate,
                            finishDate: bDTO.finishDate,
                            rating: bDTO.rating,
                            bookDescription: bDTO.bookDescription
                        )
                        modelContext.insert(newBook)
                        bookMap[newBook.id] = newBook
                    }
                }
                
                // Import Sessions
                var sessionMap: [UUID: ReadingSession] = [:]
                let existingSessions = try modelContext.fetch(FetchDescriptor<ReadingSession>())
                for s in existingSessions {
                    sessionMap[s.id] = s
                }
                
                for sDTO in package.sessions {
                    let book = sDTO.bookId != nil ? bookMap[sDTO.bookId!] : nil
                    if let existing = sessionMap[sDTO.id] {
                        existing.book = book
                        existing.startedAt = sDTO.startedAt
                        existing.endedAt = sDTO.endedAt
                        existing.statusRawValue = sDTO.status
                        existing.accumulatedActiveSeconds = sDTO.accumulatedActiveSeconds
                        existing.pausedDurationSeconds = sDTO.pausedDurationSeconds
                        existing.startPage = sDTO.startPage
                        existing.endPage = sDTO.endPage
                        existing.notes = sDTO.notes
                    } else {
                        let newSession = ReadingSession(
                            id: sDTO.id,
                            book: book,
                            startedAt: sDTO.startedAt,
                            endedAt: sDTO.endedAt,
                            status: SessionStatus(rawValue: sDTO.status) ?? .completed,
                            accumulatedActiveSeconds: sDTO.accumulatedActiveSeconds,
                            pausedDurationSeconds: sDTO.pausedDurationSeconds,
                            startPage: sDTO.startPage,
                            endPage: sDTO.endPage,
                            notes: sDTO.notes
                        )
                        modelContext.insert(newSession)
                        sessionMap[newSession.id] = newSession
                    }
                }
                
                // Import Journal Entries
                var journalMap: [UUID: JournalEntry] = [:]
                let existingJournals = try modelContext.fetch(FetchDescriptor<JournalEntry>())
                for j in existingJournals {
                    journalMap[j.id] = j
                }
                
                for jDTO in package.journalEntries {
                    let book = jDTO.bookId != nil ? bookMap[jDTO.bookId!] : nil
                    if let existing = journalMap[jDTO.id] {
                        existing.book = book
                        existing.content = jDTO.content
                        existing.entryTypeRawValue = jDTO.entryType
                        existing.pageNumber = jDTO.pageNumber
                        existing.isFavorite = jDTO.isFavorite
                    } else {
                        let newEntry = JournalEntry(
                            id: jDTO.id,
                            book: book,
                            content: jDTO.content,
                            entryType: JournalEntryType(rawValue: jDTO.entryType) ?? .note,
                            pageNumber: jDTO.pageNumber,
                            isFavorite: jDTO.isFavorite
                        )
                        modelContext.insert(newEntry)
                        journalMap[newEntry.id] = newEntry
                    }
                }
                
                // Import Goals
                if let gDTO = package.goals {
                    activeGoal.dailyMinutes = gDTO.dailyMinutes
                    activeGoal.dailyPages = gDTO.dailyPages
                    activeGoal.yearlyBookTarget = gDTO.yearlyBookTarget
                }
                
                try modelContext.save()
                loadGoalValues()
                
                importSuccessMessage = "Successfully imported \(package.books.count) books, \(package.sessions.count) sessions, and \(package.journalEntries.count) journal notes."
                importErrorMessage = nil
                showingAlert = true
            } catch {
                importErrorMessage = error.localizedDescription
                showingAlert = true
            }
            
        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

// iPadOS ShareSheet representation
public struct ShareSheet: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

