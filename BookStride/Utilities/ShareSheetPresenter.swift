//
//  ShareSheetPresenter.swift
//  BookStride
//
//  Native iPadOS share sheet, Photos library saver, Document Picker file exporter,
//  and SwiftUI ImageRenderer wrapper for Reading Wrapped cards.
//

import SwiftUI
import UIKit
import Photos
import UniformTypeIdentifiers

@MainActor
public enum WrappedCardRenderer {
    
    /// Renders a SwiftUI view to a pixel-crisp UIImage at the requested display scale.
    public static func renderImage<V: View>(
        view: V,
        size: CGSize,
        scale: CGFloat = 3.0
    ) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
    
    /// Saves a UIImage to the temporary directory with a clean, descriptive filename.
    public static func saveTemporaryPNG(image: UIImage, filename: String) -> URL? {
        // Sanitize filename
        let safeName = filename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let fullFilename = safeName.hasSuffix(".png") ? safeName : "\(safeName).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fullFilename)
        
        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }
}

public enum PhotoLibrarySaver {
    
    /// Saves a UIImage into the user's Photos library, properly handling iPadOS permissions.
    public static func saveToPhotos(image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    let err = NSError(
                        domain: "com.amitroy.BookStride.Photos",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Photos access was not granted. Please allow photo access in Settings to save cards."]
                    )
                    completion(.failure(err))
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(()))
                    } else {
                        let err = error ?? NSError(
                            domain: "com.amitroy.BookStride.Photos",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Unable to write image to the Photos library."]
                        )
                        completion(.failure(err))
                    }
                }
            }
        }
    }
}

// MARK: - iPadOS Compatible Share Sheet

public struct ActivityViewSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]?
    
    public init(activityItems: [Any], applicationActivities: [UIActivity]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        // iPadOS popover presentation safeguard
        controller.popoverPresentationController?.permittedArrowDirections = []
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            controller.popoverPresentationController?.sourceView = root.view
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: root.view.bounds.midX,
                y: root.view.bounds.midY,
                width: 0,
                height: 0
            )
        }
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - iPadOS Document Picker (Save to Files)

public struct DocumentExportPickerSheet: UIViewControllerRepresentable {
    public let fileURL: URL
    public var onCompletion: ((Bool) -> Void)?
    
    public init(fileURL: URL, onCompletion: ((Bool) -> Void)? = nil) {
        self.fileURL = fileURL
        self.onCompletion = onCompletion
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentExportPickerSheet
        
        init(_ parent: DocumentExportPickerSheet) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onCompletion?(true)
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCompletion?(false)
        }
    }
}
