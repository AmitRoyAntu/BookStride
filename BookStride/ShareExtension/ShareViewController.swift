//
//  ShareViewController.swift
//  BookStrideShareExtension
//
//  iPad and Mac Share Sheet extension providing a review and confirmation UI
//  for saving shared Apple Books links, web URLs, quotes, and EPUB/PDF files directly to BookStride.
//

#if canImport(UIKit)
import UIKit
import SwiftUI
import UniformTypeIdentifiers
#if canImport(LinkPresentation)
import LinkPresentation
#endif

@objc(ShareViewController)
public class ShareViewController: UIViewController {
    
    private var detectedType: IncomingShareType = .url
    private var detectedTitle: String = ""
    private var detectedAuthor: String = ""
    private var detectedURL: String? = nil
    private var detectedText: String? = nil
    private var detectedCoverData: Data? = nil
    private var relativeFilePath: String? = nil
    private var fileFormat: String? = nil
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        extractSharedItems()
    }
    
    private func extractSharedItems() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments, !attachments.isEmpty else {
            presentReviewView()
            return
        }
        
        let dispatchGroup = DispatchGroup()
        
        // Check for attributed content text on extensionItem (e.g. "Title by Author")
        if let contentText = extensionItem.attributedContentText?.string, !contentText.isEmpty {
            if contentText.contains(" by ") {
                let parts = contentText.components(separatedBy: " by ")
                if parts.count >= 2 {
                    if detectedTitle.isEmpty {
                        detectedTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if detectedAuthor.isEmpty {
                        detectedAuthor = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        
        for provider in attachments {
            // 1. Web URL / Apple Books link / LPLinkMetadata
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                dispatchGroup.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    defer { dispatchGroup.leave() }
                    guard let self = self else { return }
                    
                    #if canImport(LinkPresentation)
                    if let linkMeta = item as? LPLinkMetadata {
                        if let t = linkMeta.title, !t.isEmpty, self.detectedTitle.isEmpty {
                            self.detectedTitle = t
                        }
                        if let u = linkMeta.url ?? linkMeta.originalURL {
                            self.detectedURL = u.absoluteString
                            self.detectedType = .url
                            if self.detectedTitle.isEmpty, let parsed = self.parseTitleFromAppleBooksURL(u) {
                                self.detectedTitle = parsed
                            }
                        }
                        if let imgProvider = linkMeta.imageProvider ?? linkMeta.iconProvider {
                            dispatchGroup.enter()
                            imgProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] (data, _) in
                                defer { dispatchGroup.leave() }
                                if let data = data {
                                    self?.detectedCoverData = data
                                }
                            }
                        }
                        return
                    }
                    #endif
                    
                    if let url = item as? URL {
                        self.detectedType = .url
                        self.detectedURL = url.absoluteString
                        if self.detectedTitle.isEmpty {
                            if let parsed = self.parseTitleFromAppleBooksURL(url) {
                                self.detectedTitle = parsed
                            } else {
                                self.detectedTitle = url.lastPathComponent
                            }
                        }
                    }
                }
            }
            // 3. EPUB or PDF File
            else if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ||
                    provider.hasItemConformingToTypeIdentifier("org.idpf.epub-container") ||
                    provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                dispatchGroup.enter()
                let typeId = provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) ? UTType.pdf.identifier : "org.idpf.epub-container"
                provider.loadItem(forTypeIdentifier: typeId, options: nil) { [weak self] (item, error) in
                    defer { dispatchGroup.leave() }
                    guard let self = self else { return }
                    if let fileURL = item as? URL {
                        let ext = fileURL.pathExtension.lowercased()
                        if ext == "pdf" || ext == "epub" {
                            self.detectedType = .file
                            self.fileFormat = ext
                            if self.detectedTitle.isEmpty {
                                self.detectedTitle = fileURL.deletingPathExtension().lastPathComponent
                            }
                            
                            // Copy file safely into App Group files directory
                            if let filesDir = IncomingShareQueue.filesDirectoryURL {
                                let destinationFileName = "\(UUID().uuidString).\(ext)"
                                let destinationURL = filesDir.appendingPathComponent(destinationFileName)
                                try? FileManager.default.copyItem(at: fileURL, to: destinationURL)
                                self.relativeFilePath = destinationFileName
                            }
                        }
                    }
                }
            }
            // 4. Plain Text / Quote / Title String
            else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                dispatchGroup.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                    defer { dispatchGroup.leave() }
                    guard let self = self else { return }
                    if let text = item as? String {
                        self.detectedText = text
                        // Check if text is formatted as "Title by Author"
                        if text.contains(" by ") {
                            let parts = text.components(separatedBy: " by ")
                            if parts.count >= 2 {
                                if self.detectedTitle.isEmpty {
                                    self.detectedTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                                if self.detectedAuthor.isEmpty {
                                    self.detectedAuthor = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                        } else if self.detectedTitle.isEmpty {
                            self.detectedTitle = String(text.prefix(50))
                            self.detectedType = .textQuote
                        }
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.presentReviewView()
        }
    }
    
    private func parseTitleFromAppleBooksURL(_ url: URL) -> String? {
        let components = url.pathComponents
        if let bookIndex = components.firstIndex(of: "book"), bookIndex + 1 < components.count {
            let slug = components[bookIndex + 1]
            let cleaned = slug.replacingOccurrences(of: "-", with: " ").capitalized
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }
    
    private func presentReviewView() {
        let reviewView = ShareSheetReviewView(
            initialType: detectedType,
            initialTitle: detectedTitle,
            initialAuthor: detectedAuthor,
            urlString: detectedURL,
            textContent: detectedText,
            relativeFilePath: relativeFilePath,
            fileFormat: fileFormat,
            coverImageData: detectedCoverData,
            onSave: { [weak self] item in
                // 1. Enqueue to App Group storage if provisioned
                try? IncomingShareQueue.enqueue(item)
                
                // 2. Transmit via deep link directly to host application (zero-dependency on device provisioning)
                self?.openHostApplication(with: item)
                
                // 3. Complete share sheet request cleanly
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            },
            onCancel: { [weak self] in
                let cancelError = NSError(domain: "com.amitroy.BookStride.ShareExtension", code: NSUserCancelledError, userInfo: nil)
                self?.extensionContext?.cancelRequest(withError: cancelError)
            }
        )
        
        let hostingController = UIHostingController(rootView: reviewView)
        hostingController.modalPresentationStyle = .formSheet
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
    
    private func openHostApplication(with item: IncomingShareItem) {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "action", value: "addBook"),
            URLQueryItem(name: "title", value: item.title),
            URLQueryItem(name: "author", value: item.author),
            URLQueryItem(name: "dest", value: item.targetDestination)
        ]
        if let u = item.urlString {
            queryItems.append(URLQueryItem(name: "url", value: u))
        }
        if let p = item.totalPages {
            queryItems.append(URLQueryItem(name: "pages", value: "\(p)"))
        }
        if let f = item.fileFormat {
            queryItems.append(URLQueryItem(name: "format", value: f))
        }
        
        // Compact JSON data fallback for guaranteed parsing
        var compactItem = item
        if (compactItem.coverImageData?.count ?? 0) > 30_000 {
            compactItem.coverImageData = nil // keep deep link within standard URL length limits
        }
        if let data = try? JSONEncoder().encode(compactItem) {
            queryItems.append(URLQueryItem(name: "data", value: data.base64EncodedString()))
        }
        
        var components = URLComponents()
        components.scheme = "bookstride"
        components.host = "incoming"
        components.queryItems = queryItems
        
        guard let url = components.url else { return }
        
        // 1. In extensions, extensionContext.open(_:completionHandler:) is the designated API
        self.extensionContext?.open(url, completionHandler: nil)
        
        // 2. Also try responder chain fallback
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                break
            }
            responder = responder?.next
        }
    }
}

struct ShareSheetReviewView: View {
    @State private var itemType: IncomingShareType
    @State private var title: String
    @State private var author: String
    @State private var totalPagesText: String = ""
    @State private var destination: String // "library" or "journal"
    
    let urlString: String?
    let textContent: String?
    let relativeFilePath: String?
    let fileFormat: String?
    let coverImageData: Data?
    
    let onSave: (IncomingShareItem) -> Void
    let onCancel: () -> Void
    
    init(
        initialType: IncomingShareType,
        initialTitle: String,
        initialAuthor: String,
        urlString: String?,
        textContent: String?,
        relativeFilePath: String?,
        fileFormat: String?,
        coverImageData: Data? = nil,
        onSave: @escaping (IncomingShareItem) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _itemType = State(initialValue: initialType)
        _title = State(initialValue: initialTitle.isEmpty ? "New Book" : initialTitle)
        _author = State(initialValue: initialAuthor)
        _destination = State(initialValue: initialType == .textQuote ? "journal" : "library")
        self.urlString = urlString
        self.textContent = textContent
        self.relativeFilePath = relativeFilePath
        self.fileFormat = fileFormat
        self.coverImageData = coverImageData
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    private var isAppleBooksLink: Bool {
        guard let url = urlString?.lowercased() else { return false }
        return url.contains("books.apple.com") || url.contains("ibooks://") || url.contains("itms-books://")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Shared Content") {
                    HStack(alignment: .top, spacing: 14) {
                        if let coverData = coverImageData, let uiImage = UIImage(data: coverData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 75)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "E4DFD3"), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                        } else {
                            Image(systemName: iconName)
                                .font(.title)
                                .foregroundColor(Color(hex: "2D5A43"))
                                .frame(width: 44, height: 44)
                                .background(Color(hex: "2D5A43").opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(typeLabel)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(Color(hex: "2D5A43"))
                                
                                if isAppleBooksLink {
                                    HStack(spacing: 3) {
                                        Image(systemName: "book.fill")
                                        Text("Apple Books")
                                    }
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(Color(hex: "2D5A43"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "2D5A43").opacity(0.15))
                                    .clipShape(Capsule())
                                }
                            }
                            
                            if let url = urlString {
                                Text(url)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            } else if let text = textContent {
                                Text("\"\(text)\"")
                                    .font(.caption2.italic())
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            } else if let format = fileFormat {
                                Text("Format: \(format.uppercased())")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Book Details") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    if destination == "library" {
                        TextField("Number of Pages (optional)", text: $totalPagesText)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section("Save Destination") {
                    Picker("Destination", selection: $destination) {
                        Text("Add to Library").tag("library")
                        Text("Save to Journal").tag("journal")
                    }
                    .pickerStyle(.segmented)
                }
                
                if destination == "library" && isAppleBooksLink {
                    Section {
                        Label("Direct link will be stored so you can tap 'Read in Apple Books' at any time.", systemImage: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Save to BookStride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let parsedPages = Int(totalPagesText.trimmingCharacters(in: .whitespacesAndNewlines))
                        let item = IncomingShareItem(
                            type: itemType,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                            urlString: urlString,
                            textContent: textContent,
                            targetDestination: destination,
                            relativeFilePath: relativeFilePath,
                            fileFormat: fileFormat,
                            totalPages: parsedPages,
                            coverImageData: coverImageData
                        )
                        onSave(item)
                    }
                    .fontWeight(.semibold)
                    .tint(Color(hex: "2D5A43"))
                }
            }
        }
    }
    
    private var iconName: String {
        switch itemType {
        case .url: return isAppleBooksLink ? "book.fill" : "link"
        case .textQuote: return "quote.bubble.fill"
        case .file: return "doc.fill"
        }
    }
    
    private var typeLabel: String {
        switch itemType {
        case .url: return isAppleBooksLink ? "Apple Book" : "Web Link"
        case .textQuote: return "Quote / Highlight"
        case .file: return "Book File (\(fileFormat?.uppercased() ?? ""))"
        }
    }
}
#endif


