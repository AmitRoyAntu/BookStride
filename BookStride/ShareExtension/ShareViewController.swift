//
//  ShareViewController.swift
//  BookStrideShareExtension
//
//  iPad Share Sheet extension providing a review and confirmation UI
//  for saving shared web URLs, quotes, and EPUB/PDF files directly to BookStride.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

@objc(ShareViewController)
public class ShareViewController: UIViewController {
    
    private var detectedType: IncomingShareType = .textQuote
    private var detectedTitle: String = ""
    private var detectedAuthor: String = ""
    private var detectedURL: String? = nil
    private var detectedText: String? = nil
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
        
        for provider in attachments {
            // 1. Check for URL
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                dispatchGroup.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    defer { dispatchGroup.leave() }
                    guard let self = self else { return }
                    if let url = item as? URL {
                        self.detectedType = .url
                        self.detectedURL = url.absoluteString
                        self.detectedTitle = extensionItem.attributedContentText?.string ?? url.lastPathComponent
                    }
                }
            }
            // 2. Check for EPUB or PDF File
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
                            self.detectedTitle = fileURL.deletingPathExtension().lastPathComponent
                            
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
            // 3. Check for Plain Text / Quote
            else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                dispatchGroup.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                    defer { dispatchGroup.leave() }
                    guard let self = self else { return }
                    if let text = item as? String {
                        self.detectedType = .textQuote
                        self.detectedText = text
                        self.detectedTitle = String(text.prefix(40))
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.presentReviewView()
        }
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
            onSave: { [weak self] item in
                do {
                    try IncomingShareQueue.enqueue(item)
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                } catch {
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
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
}

struct ShareSheetReviewView: View {
    @State private var itemType: IncomingShareType
    @State private var title: String
    @State private var author: String
    @State private var destination: String // "library" or "journal"
    
    let urlString: String?
    let textContent: String?
    let relativeFilePath: String?
    let fileFormat: String?
    
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
        onSave: @escaping (IncomingShareItem) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _itemType = State(initialValue: initialType)
        _title = State(initialValue: initialTitle.isEmpty ? "New Shared Item" : initialTitle)
        _author = State(initialValue: initialAuthor)
        _destination = State(initialValue: initialType == .textQuote ? "journal" : "library")
        self.urlString = urlString
        self.textContent = textContent
        self.relativeFilePath = relativeFilePath
        self.fileFormat = fileFormat
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Shared Content") {
                    HStack(spacing: 12) {
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundColor(Color(hex: "2D5A43"))
                            .frame(width: 36, height: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(typeLabel)
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color(hex: "2D5A43"))
                            
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
                
                Section("Details") {
                    TextField("Title", text: $title)
                    if destination == "library" {
                        TextField("Author (optional)", text: $author)
                    }
                }
                
                Section("Save Destination") {
                    Picker("Destination", selection: $destination) {
                        Text("Add to Library").tag("library")
                        Text("Save to Journal").tag("journal")
                    }
                    .pickerStyle(.segmented)
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
                        let item = IncomingShareItem(
                            type: itemType,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                            urlString: urlString,
                            textContent: textContent,
                            targetDestination: destination,
                            relativeFilePath: relativeFilePath,
                            fileFormat: fileFormat
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
        case .url: return "link"
        case .textQuote: return "quote.bubble.fill"
        case .file: return "doc.fill"
        }
    }
    
    private var typeLabel: String {
        switch itemType {
        case .url: return "Web Link"
        case .textQuote: return "Quote / Highlight"
        case .file: return "Book File (\(fileFormat?.uppercased() ?? ""))"
        }
    }
}

