//
//  ReadingWrappedView.swift
//  BookStride
//
//  Interactive Reading Wrapped hub allowing users to browse monthly and annual
//  recaps, customize card styling, preview live, and share or save cards.
//

import SwiftUI
import SwiftData

public enum WrappedScope: String, CaseIterable, Identifiable {
    case monthly = "Monthly Wrapped"
    case yearly = "Yearly Wrapped"
    
    public var id: String { rawValue }
}

public struct ReadingWrappedView: View {
    @Query(sort: \ReadingSession.startedAt, order: .reverse)
    private var allSessions: [ReadingSession]
    
    @Query(sort: \Book.updatedAt, order: .reverse)
    private var allBooks: [Book]
    
    // Period selection
    @State private var selectedScope: WrappedScope = .monthly
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    // Customization
    @State private var customization = WrappedCardCustomization()
    @State private var showingCustomizationSheet: Bool = false
    
    // Export state
    @State private var renderedCardImage: UIImage? = nil
    @State private var exportedFileURL: URL? = nil
    @State private var showingShareSheet: Bool = false
    @State private var showingDocumentPicker: Bool = false
    @State private var showingPhotosSuccessAlert: Bool = false
    @State private var photosAlertMessage: String = ""
    @State private var showingErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isExporting: Bool = false
    
    public init() {}
    
    // Convert SwiftData models to DTOs for safe, clean calculation
    private var sessionDTOs: [ReadingSessionDTO] {
        allSessions.map { s in
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
                notes: s.notes
            )
        }
    }
    
    private var bookDTOs: [BookDTO] {
        allBooks.map { b in
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
    }
    
    // Computed monthly data
    private var currentMonthlyData: MonthlyWrappedData {
        ReadingWrappedService.computeMonthlyWrapped(
            month: selectedMonth,
            year: selectedYear,
            sessions: sessionDTOs,
            books: bookDTOs
        )
    }
    
    // Computed yearly data
    private var currentYearlyData: YearlyWrappedData {
        ReadingWrappedService.computeYearlyWrapped(
            year: selectedYear,
            sessions: sessionDTOs,
            books: bookDTOs
        )
    }
    
    private var isPeriodEmpty: Bool {
        selectedScope == .monthly ? currentMonthlyData.isEmpty : currentYearlyData.isEmpty
    }
    
    // Available years with data
    private var availableYears: [Int] {
        let currentY = Calendar.current.component(.year, from: Date())
        var yearSet = Set<Int>([currentY, currentY - 1])
        for s in allSessions {
            yearSet.insert(Calendar.current.component(.year, from: s.startedAt))
        }
        for b in allBooks {
            if let fDate = b.finishDate {
                yearSet.insert(Calendar.current.component(.year, from: fDate))
            }
        }
        return Array(yearSet).sorted(by: >)
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Scope & Period Selectors Bar
                periodControlBar
                
                // 2. Format & Theme Selectors
                stylingControlBar
                
                // 3. Card Preview or Empty State
                if isPeriodEmpty {
                    emptyPeriodCard
                } else {
                    cardPreviewArea
                }
                
                // 4. Primary Share & Save Action Bar
                if !isPeriodEmpty {
                    exportActionsBar
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .BookStrideBackground()
        .navigationTitle("Reading Wrapped")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCustomizationSheet = true
                } label: {
                    Label("Options", systemImage: "slider.horizontal.3")
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
        }
        .sheet(isPresented: $showingCustomizationSheet) {
            customizationOptionsSheet
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedFileURL {
                ActivityViewSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            if let url = exportedFileURL {
                DocumentExportPickerSheet(fileURL: url)
            }
        }
        .alert("Saved to Photos", isPresented: $showingPhotosSuccessAlert) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("Your Reading Wrapped card has been saved to your Photos library.")
        }
        .alert("Unable to Save", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Subviews
    
    private var periodControlBar: some View {
        VStack(spacing: 16) {
            Picker("Scope", selection: $selectedScope) {
                ForEach(WrappedScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400)
            
            HStack(spacing: 16) {
                if selectedScope == .monthly {
                    // Month Navigation & Picker
                    Button {
                        decrementMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(BookStrideTheme.forestGreen)
                            .padding(10)
                            .background(BookStrideTheme.cardLight)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(BookStrideTheme.borderLight, lineWidth: 1))
                    }
                    
                    Menu {
                        ForEach(1...12, id: \.self) { m in
                            Button(monthName(m)) {
                                selectedMonth = m
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("\(monthName(selectedMonth)) \(String(selectedYear))")
                                .font(.system(.headline, design: .serif))
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundColor(BookStrideTheme.mutedSlate)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(BookStrideTheme.cardLight)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                        )
                    }
                    
                    Button {
                        incrementMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(BookStrideTheme.forestGreen)
                            .padding(10)
                            .background(BookStrideTheme.cardLight)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(BookStrideTheme.borderLight, lineWidth: 1))
                    }
                } else {
                    // Year Picker
                    Menu {
                        ForEach(availableYears, id: \.self) { y in
                            Button("\(y)") {
                                selectedYear = y
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Year: \(String(selectedYear))")
                                .font(.system(.headline, design: .serif))
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundColor(BookStrideTheme.mutedSlate)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(BookStrideTheme.cardLight)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(18)
        .BookStrideCardStyle()
    }
    
    private var stylingControlBar: some View {
        HStack(spacing: 20) {
            // Format Picker (Story vs Square)
            Picker("Format", selection: $customization.format) {
                ForEach(WrappedCardFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
            
            Spacer()
            
            // Theme Style Picker
            Picker("Style", selection: $customization.theme) {
                ForEach(WrappedThemeStyle.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
        }
        .padding(.horizontal, 4)
    }
    
    private var cardPreviewArea: some View {
        VStack(spacing: 12) {
            // Live Card View
            ReadingWrappedCardView(
                monthlyData: selectedScope == .monthly ? currentMonthlyData : nil,
                yearlyData: selectedScope == .yearly ? currentYearlyData : nil,
                config: customization
            )
            .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
            .scaleEffect(previewScaleFactor)
            .frame(
                width: customization.format.designSize.width * previewScaleFactor,
                height: customization.format.designSize.height * previewScaleFactor
            )
            .padding(.vertical, 8)
            
            Text("Preview · Tap Options in the toolbar to customize included details")
                .font(.caption2)
                .foregroundColor(BookStrideTheme.mutedSlate)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(BookStrideTheme.cardLight.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                )
        )
    }
    
    private var emptyPeriodCard: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 48))
                .foregroundColor(BookStrideTheme.forestGreen.opacity(0.6))
            
            VStack(spacing: 6) {
                Text(selectedScope == .monthly ? "No Reading in \(monthName(selectedMonth)) \(selectedYear)" : "No Reading in \(selectedYear)")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                
                Text("Start a reading session with any book in your library to start generating your personal Wrapped cards.")
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }
            
            // Button to jump to latest month with data
            if let latestSession = allSessions.first {
                Button {
                    let cal = Calendar.current
                    selectedMonth = cal.component(.month, from: latestSession.startedAt)
                    selectedYear = cal.component(.year, from: latestSession.startedAt)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Jump to Latest Active Month")
                    }
                    .font(.callout.weight(.medium))
                    .foregroundColor(BookStrideTheme.forestGreen)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(BookStrideTheme.cardLight)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(BookStrideTheme.forestGreen.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .BookStrideCardStyle()
    }
    
    private var exportActionsBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                shareButton
                saveToPhotosButton
                saveToFilesButton
            }
            VStack(spacing: 12) {
                shareButton
                HStack(spacing: 12) {
                    saveToPhotosButton
                    saveToFilesButton
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var shareButton: some View {
        Button {
            triggerExportAndShare()
        } label: {
            HStack(spacing: 8) {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text("Share Card")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(BookStrideTheme.forestGreen)
            .cornerRadius(14)
        }
        .disabled(isExporting)
    }
    
    private var saveToPhotosButton: some View {
        Button {
            triggerSaveToPhotos()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "photo.badge.arrow.down")
                Text("Save to Photos")
                    .lineLimit(1)
            }
            .font(.callout.weight(.medium))
            .foregroundColor(BookStrideTheme.deepCharcoal)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(BookStrideTheme.cardLight)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(BookStrideTheme.borderLight, lineWidth: 1)
            )
            .cornerRadius(14)
        }
    }
    
    private var saveToFilesButton: some View {
        Button {
            triggerSaveToFiles()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.plus")
                Text("Save to Files")
                    .lineLimit(1)
            }
            .font(.callout.weight(.medium))
            .foregroundColor(BookStrideTheme.deepCharcoal)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(BookStrideTheme.cardLight)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(BookStrideTheme.borderLight, lineWidth: 1)
            )
            .cornerRadius(14)
        }
    }
    
    private var customizationOptionsSheet: some View {
        NavigationStack {
            Form {
                Section("Visual Theme & Format") {
                    Picker("Format Template", selection: $customization.format) {
                        ForEach(WrappedCardFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    
                    Picker("Color Theme", selection: $customization.theme) {
                        ForEach(WrappedThemeStyle.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                }
                
                Section("Included Information") {
                    Toggle("Book Cover Collage", isOn: $customization.showCovers)
                    Toggle("Most-Read Book", isOn: $customization.showMostRead)
                    Toggle("Highlights & Milestones", isOn: $customization.showHighlights)
                    if selectedScope == .monthly {
                        Toggle("Longest Session", isOn: $customization.showLongestSession)
                    }
                }
                
                Section {
                    Text("Privacy note: Reading Wrapped cards never include personal journal notes or quotes. All cards are rendered entirely on your iPad.")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
            }
            .navigationTitle("Card Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingCustomizationSheet = false
                    }
                    .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Handlers & Render Actions
    
    private var previewScaleFactor: CGFloat {
        // Adjust scale smoothly depending on format
        customization.format == .story ? 0.88 : 0.95
    }
    
    private var descriptiveFilename: String {
        if selectedScope == .monthly {
            let mName = monthName(selectedMonth)
            return "Bookstride-Monthly-Wrapped-\(mName)-\(selectedYear).png"
        } else {
            return "Bookstride-Annual-Wrapped-\(selectedYear).png"
        }
    }
    
    @MainActor
    private func generateCardUIImage() -> UIImage? {
        let card = ReadingWrappedCardView(
            monthlyData: selectedScope == .monthly ? currentMonthlyData : nil,
            yearlyData: selectedScope == .yearly ? currentYearlyData : nil,
            config: customization
        )
        return WrappedCardRenderer.renderImage(
            view: card,
            size: customization.format.designSize,
            scale: customization.format.renderScale
        )
    }
    
    private func triggerExportAndShare() {
        isExporting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let image = generateCardUIImage(),
                  let fileURL = WrappedCardRenderer.saveTemporaryPNG(image: image, filename: descriptiveFilename) else {
                isExporting = false
                errorMessage = "Could not render the card image."
                showingErrorAlert = true
                return
            }
            
            self.renderedCardImage = image
            self.exportedFileURL = fileURL
            self.isExporting = false
            self.showingShareSheet = true
        }
    }
    
    private func triggerSaveToPhotos() {
        guard let image = generateCardUIImage() else {
            errorMessage = "Could not generate card image."
            showingErrorAlert = true
            return
        }
        
        PhotoLibrarySaver.saveToPhotos(image: image) { result in
            switch result {
            case .success:
                showingPhotosSuccessAlert = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
    
    private func triggerSaveToFiles() {
        guard let image = generateCardUIImage(),
              let fileURL = WrappedCardRenderer.saveTemporaryPNG(image: image, filename: descriptiveFilename) else {
            errorMessage = "Could not prepare file for export."
            showingErrorAlert = true
            return
        }
        
        self.exportedFileURL = fileURL
        self.showingDocumentPicker = true
    }
    
    private func decrementMonth() {
        if selectedMonth > 1 {
            selectedMonth -= 1
        } else {
            selectedMonth = 12
            selectedYear -= 1
        }
    }
    
    private func incrementMonth() {
        if selectedMonth < 12 {
            selectedMonth += 1
        } else {
            selectedMonth = 1
            selectedYear += 1
        }
    }
    
    private func monthName(_ month: Int) -> String {
        let df = DateFormatter()
        return df.monthSymbols[max(0, min(11, month - 1))]
    }
}
