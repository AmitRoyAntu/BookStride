//
//  DocumentCameraScannerView.swift
//  BookStride
//
//  UIViewControllerRepresentable wrapping Apple's VNDocumentCameraViewController
//  for physical book page scanning with auto-crop and contrast enhancement.
//

import SwiftUI
import VisionKit

public struct DocumentCameraScannerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    public var onScanCompleted: (UIImage) -> Void
    public var onCancel: () -> Void
    
    public init(
        onScanCompleted: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.onScanCompleted = onScanCompleted
        self.onCancel = onCancel
    }
    
    /// Whether the device hardware supports Apple's document camera scanner.
    public static var isSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    public class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraScannerView
        
        init(parent: DocumentCameraScannerView) {
            self.parent = parent
        }
        
        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                parent.onCancel()
                parent.dismiss()
                return
            }
            let image = scan.imageOfPage(at: 0)
            parent.onScanCompleted(image)
            parent.dismiss()
        }
        
        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
            parent.dismiss()
        }
        
        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
            parent.dismiss()
        }
    }
}
