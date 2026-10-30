//
//  ShareSheetPresenter.swift
//  BookStride
//
//  Cross-platform sharing, Photos library saving, Document Picker file exporter,
//  and SwiftUI ImageRenderer wrapper for Reading Wrapped cards.
//

import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
import Photos
import LinkPresentation
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

@MainActor
public enum WrappedCardRenderer {
    
    /// Renders a SwiftUI view to a pixel-crisp image at the requested display scale.
    public static func renderImage<V: View>(
        view: V,
        size: CGSize,
        scale: CGFloat = 2.0
    ) -> PlatformImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        #if canImport(UIKit)
        return renderer.uiImage
        #elseif canImport(AppKit)
        return renderer.nsImage
        #endif
    }
    
    /// Saves an image to the temporary directory with a clean, descriptive filename.
    public static func saveTemporaryPNG(image: PlatformImage, filename: String) -> URL? {
        let safeName = filename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let fullFilename = safeName.hasSuffix(".png") ? safeName : "\(safeName).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fullFilename)
        
        #if canImport(UIKit)
        guard let data = image.pngData() else { return nil }
        #elseif canImport(AppKit)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:]) else { return nil }
        #endif
        
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }
}

#if canImport(UIKit)
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

// MARK: - Activity Item Source with Link Metadata

public final class ShareActivityItemSource: NSObject, UIActivityItemSource {
    public let fileURL: URL
    public let itemTitle: String
    public let previewImage: UIImage?
    
    public init(fileURL: URL, itemTitle: String, previewImage: UIImage? = nil) {
        self.fileURL = fileURL
        self.itemTitle = itemTitle
        self.previewImage = previewImage
        super.init()
    }
    
    public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }
    
    public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        fileURL
    }
    
    public func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = itemTitle
        if let image = previewImage {
            metadata.imageProvider = NSItemProvider(object: image)
        } else {
            let iconName: String
            switch fileURL.pathExtension.lowercased() {
            case "json":
                iconName = "doc.badge.gearshape"
            case "csv":
                iconName = "tablecells"
            default:
                iconName = "doc.text"
            }
            if let img = UIImage(systemName: iconName) {
                metadata.iconProvider = NSItemProvider(object: img)
            }
        }
        return metadata
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
        let items: [Any]
        if let first = activityItems.first as? URL {
            let itemTitle = first.deletingPathExtension().lastPathComponent
            let source = ShareActivityItemSource(fileURL: first, itemTitle: itemTitle)
            items = [source]
        } else {
            items = activityItems
        }
        
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: applicationActivities
        )
        
        if let popover = controller.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                popover.sourceView = rootVC.view
                let bounds = rootVC.view.bounds
                popover.sourceRect = CGRect(x: bounds.midX - 10, y: bounds.midY - 10, width: 20, height: 20)
                popover.permittedArrowDirections = []
            }
        }
        
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]
        
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

public struct DocumentExportPickerSheet: UIViewControllerRepresentable {
    public let fileURL: URL
    public let onCompletion: ((Bool) -> Void)?
    
    public init(fileURL: URL, onCompletion: ((Bool) -> Void)? = nil) {
        self.fileURL = fileURL
        self.onCompletion = onCompletion
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onCompletion: ((Bool) -> Void)?
        
        init(onCompletion: ((Bool) -> Void)?) {
            self.onCompletion = onCompletion
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onCompletion?(true)
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion?(false)
        }
    }
}
#endif
