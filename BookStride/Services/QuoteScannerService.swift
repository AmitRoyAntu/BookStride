//
//  QuoteScannerService.swift
//  BookStride
//
//  OCR service using Apple's Vision framework to scan physical book pages and extract
//  quotes directly on-device without cloud dependencies.
//

import Foundation
@preconcurrency import Vision
#if canImport(UIKit)
import UIKit
#endif

/// The result returned after processing a book page image.
public struct ScannedQuoteResult: Sendable {
    public let fullText: String
    public let detectedPageNumber: Int?
    public let lineCount: Int
    
    public init(
        fullText: String,
        detectedPageNumber: Int? = nil,
        lineCount: Int = 0
    ) {
        self.fullText = fullText
        self.detectedPageNumber = detectedPageNumber
        self.lineCount = lineCount
    }
}

/// Pure text processing helpers for clean OCR text extraction and page parsing.
public struct QuoteTextProcessor: Sendable {
    
    /// Parses an integer page number from strings like "142", "Page 142", "p. 142", "- 142 -".
    public static func parsePageNumber(from string: String) -> Int? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Remove common page prefixes and decorative marks
        let cleaned = trimmed
            .replacingOccurrences(of: "Page", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "p.", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "•", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        // Check standard digits
        if let val = Int(cleaned), val > 0 && val < 10000 {
            return val
        }
        
        return nil
    }
    
    /// Cleans recognized lines: strips standalone page numbers and joins hyphenated line breaks.
    public static func cleanExtractedLines(_ rawLines: [String]) -> (cleanedText: String, detectedPageNumber: Int?) {
        guard !rawLines.isEmpty else {
            return ("", nil)
        }
        
        var lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var detectedPageNumber: Int? = nil
        
        // Check first line for standalone page number or header
        if let first = lines.first, let page = parsePageNumber(from: first) {
            detectedPageNumber = page
            lines.removeFirst()
        }
        
        // Check last line for standalone page number or footer if not found yet
        if detectedPageNumber == nil, let last = lines.last, let page = parsePageNumber(from: last) {
            detectedPageNumber = page
            lines.removeLast()
        }
        
        guard !lines.isEmpty else {
            return ("", detectedPageNumber)
        }
        
        // Stitch lines together while joining hyphenated line breaks (e.g. "re- \n markable" -> "remarkable")
        var result = ""
        for i in 0..<lines.count {
            let currentLine = lines[i]
            
            if result.isEmpty {
                result = currentLine
            } else if result.hasSuffix("-") && !result.hasSuffix("--") {
                // Remove hyphen and stitch directly without space
                result.removeLast()
                result += currentLine
            } else {
                result += " " + currentLine
            }
        }
        
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned, detectedPageNumber)
    }
}

/// Service that coordinates Vision OCR requests on background threads.
public final class QuoteScannerService: Sendable {
    public static let shared = QuoteScannerService()
    
    public init() {}
    
    /// Performs text recognition on the given CGImage.
    public func recognizeText(from cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> ScannedQuoteResult {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ScannedQuoteResult(fullText: ""))
                    return
                }
                
                // Sort observations by vertical top-to-bottom position (Vision coordinates: y=0 is bottom, y=1 is top)
                let sortedObservations = observations.sorted { obs1, obs2 in
                    obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
                }
                
                let rawLines = sortedObservations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let (cleanedText, detectedPage) = QuoteTextProcessor.cleanExtractedLines(rawLines)
                let result = ScannedQuoteResult(
                    fullText: cleanedText,
                    detectedPageNumber: detectedPage,
                    lineCount: rawLines.count
                )
                continuation.resume(returning: result)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            if #available(iOS 16.0, macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }
            
            // Prioritize English and supported system languages
            request.recognitionLanguages = ["en-US"]
            
            // Execute on background queue
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    #if canImport(UIKit)
    /// Performs text recognition on the given UIImage.
    public func recognizeText(from image: UIImage) async throws -> ScannedQuoteResult {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "BookStride.QuoteScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not retrieve CGImage from provided photo."])
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await recognizeText(from: cgImage, orientation: orientation)
    }
    #endif
}

#if canImport(UIKit)
// MARK: - UIImage Orientation Helper
private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
