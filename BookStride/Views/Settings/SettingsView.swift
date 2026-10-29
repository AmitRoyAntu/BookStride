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
    @State private var showingJSONExportDialog: Bool = false
    @State private var showingCSVExportDialog: Bool = false
    @State private var exportedURLs: [URL] = []
    @State private var showingDocumentPicker: Bool = false
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
            
            // Section 3: Streak Rule Explanation & Reminders
            Section(header: Text("How Streaks Work")) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Transparent Habit Counting", systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    
                    Text("• A calendar day qualifies for your streak once your active reading reaches your daily goal (\(dailyMinutes) min).\n• While today is underway, an active streak from yesterday is never prematurely broken.\n• Paused intervals are strictly deducted from active time.\n• Sessions crossing local midnight credit their active minutes to the respective calendar days.")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                        .lineSpacing(4)
                }
                .padding(.vertical, 4)
            }
            
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
            .alert("Notification Permission Denied", isPresented: $showingPermissionDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enable notifications for BookStride in iPadOS Settings to receive daily reading reminders.")
            }
            
            // Section 4: Data Management (Export & Import)
            Section(header: Text("Data Management & Backup")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Data Scope")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    Text("\(allBooks.count) Books • \(allSessions.count) Sessions • \(allJournalEntries.count) Journal Notes")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                .padding(.vertical, 4)
                
                Button {
                    prepareJSONBackupExport()
                } label: {
                    HStack {
                        Image(systemName: "archivebox.fill")
                        Text("Export Full Backup (JSON)")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption2)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button {
                    prepareCSVSpreadsheetsExport()
                } label: {
                    HStack {
                        Image(systemName: "tablecells.fill")
                        Text("Export Spreadsheets (CSV)")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption2)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button {
                    showingFileImporter = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Backup (JSON)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                HStack {
                    Text("Offline-first:")
                    Spacer()
                    Text("All data is stored locally on this iPad")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
            }
            .confirmationDialog("Export Full Backup", isPresented: $showingJSONExportDialog, titleVisibility: .visible) {
                Button("Save to Files (iCloud / Local)") {
                    showingDocumentPicker = true
                }
                Button("Share via AirDrop or Apps...") {
                    showingShareSheet = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save your complete Bookstride library, reading history, and journal notes to a JSON file.")
            }
            .confirmationDialog("Export Spreadsheets", isPresented: $showingCSVExportDialog, titleVisibility: .visible) {
                Button("Save to Files (iCloud / Local)") {
                    showingDocumentPicker = true
                }
                Button("Share via AirDrop or Apps...") {
                    showingShareSheet = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Export books, reading sessions, and journal entries as RFC 4180 CSV spreadsheets.")
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentExportPickerSheet(urls: exportedURLs) { success in
                    if success {
                        importSuccessMessage = "Files saved successfully to the selected folder."
                        importErrorMessage = nil
                        showingAlert = true
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ActivityViewSheet(activityItems: exportedURLs)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert(importErrorMessage != nil ? "Data Management Notice" : "Data Management", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? importSuccessMessage ?? "")
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .alert("Sample Data Added", isPresented: $showingSampleDataPopulatedNotice) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Sample books, reading sessions spanning streaks, and journal notes have been loaded.")
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .alert("Clear All App Data?", isPresented: $showingClearConfirmation) {
                    Button("Erase Everything", role: .destructive) {
                        clearAllLibraryData()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all books, reading sessions, and journal entries. This cannot be undone.")
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
        prepareJSONBackupExport()
    }
    
    private func prepareJSONBackupExport() {
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
                appleBooksURL: b.appleBooksURL,
                importedFileName: b.importedFileName,
                sourceFormat: b.sourceFormatRawValue,
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
            self.exportedURLs = [fileURL]
            self.showingJSONExportDialog = true
        } catch {
            importErrorMessage = "Failed to export backup: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func prepareCSVSpreadsheetsExport() {
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
                appleBooksURL: b.appleBooksURL,
                importedFileName: b.importedFileName,
                sourceFormat: b.sourceFormatRawValue,
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
        
        do {
            let urls = try DataExportService.writeCSVExportFiles(
                bookDTOs: bookDTOs,
                sessionDTOs: sessionDTOs,
                journalDTOs: journalDTOs
            )
            self.exportedURLs = urls
            self.showingCSVExportDialog = true
        } catch {
            importErrorMessage = "Failed to export CSV: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    @MainActor
    private func clearAllLibraryData() {
        do {
            let sessions = try modelContext.fetch(FetchDescriptor<ReadingSession>())
            for s in sessions {
                modelContext.delete(s)
            }
            
            let entries = try modelContext.fetch(FetchDescriptor<JournalEntry>())
            for e in entries {
                modelContext.delete(e)
            }
            
            let books = try modelContext.fetch(FetchDescriptor<Book>())
            for b in books {
                modelContext.delete(b)
            }
            
            try modelContext.save()
            
            // Sync empty session to widget
            ReadingTimerService.shared.updateWidgetSnapshot()
            
            importSuccessMessage = "All library books, sessions, and journal notes have been cleared."
            importErrorMessage = nil
            showingAlert = true
        } catch {
            SampleDataService.clearAllData(in: modelContext)
            ReadingTimerService.shared.updateWidgetSnapshot()
            importErrorMessage = "Failed to clear data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            var fileData: Data?
            var coordinatorError: NSError?
            var fileReadError: Error?
            
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinatorError) { coordinatedURL in
                do {
                    fileData = try Data(contentsOf: coordinatedURL)
                } catch {
                    fileReadError = error
                }
            }
            
            if let err = coordinatorError {
                importErrorMessage = "Access error: \(err.localizedDescription)"
                showingAlert = true
                return
            }
            if let err = fileReadError {
                importErrorMessage = "File read error: \(err.localizedDescription)"
                showingAlert = true
                return
            }
            guard let data = fileData else {
                importErrorMessage = "The selected file could not be read."
                showingAlert = true
                return
            }
            
            do {
                let package = try DataExportService.parseAndValidateJSON(data)
                
                // Import into SwiftData with duplicate avoidance by ID
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
                        existing.appleBooksURL = bDTO.appleBooksURL
                        existing.importedFileName = bDTO.importedFileName
                        existing.sourceFormatRawValue = bDTO.sourceFormat
                        existing.updatedAt = bDTO.updatedAt
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
                            bookDescription: bDTO.bookDescription,
                            appleBooksURL: bDTO.appleBooksURL,
                            importedFileName: bDTO.importedFileName,
                            sourceFormat: BookSourceFormat(rawValue: bDTO.sourceFormat ?? "Manual") ?? .manual,
                            createdAt: bDTO.createdAt,
                            updatedAt: bDTO.updatedAt
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
                        existing.updatedAt = sDTO.updatedAt
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
                            notes: sDTO.notes,
                            createdAt: sDTO.createdAt,
                            updatedAt: sDTO.updatedAt
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
                        existing.updatedAt = jDTO.updatedAt
                    } else {
                        let newEntry = JournalEntry(
                            id: jDTO.id,
                            book: book,
                            content: jDTO.content,
                            entryType: JournalEntryType(rawValue: jDTO.entryType) ?? .note,
                            pageNumber: jDTO.pageNumber,
                            isFavorite: jDTO.isFavorite,
                            createdAt: jDTO.createdAt,
                            updatedAt: jDTO.updatedAt
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
                
                // Sync updated reading progress to Widget
                ReadingTimerService.shared.updateWidgetSnapshot()
                
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
