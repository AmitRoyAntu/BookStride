//
//  BookImportService.swift
//  BookStride
//
//  Extracts metadata and thumbnails from compatible EPUB and PDF files.
//  Detects DRM protection, avoids large file storage duplication, and detects library duplicates.
//

import Foundation
import PDFKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import zlib

public enum BookImportError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case securityScopeAccessDenied
    case corruptedFile(String)
    case drmProtected(String)
    case unreadableFile
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "The file format \".\(ext.uppercased())\" is not supported. Please import an EPUB or PDF."
        case .securityScopeAccessDenied:
            return "Permission to access this document was denied by iPadOS security."
        case .corruptedFile(let reason):
            return "Unable to parse book: \(reason)"
        case .drmProtected(let details):
            return "This file is protected by Digital Rights Management (DRM). Bookstride cannot read DRM-protected files: \(details)"
        case .unreadableFile:
            return "The selected file could not be read."
        }
    }
}

public struct ExtractedBookMetadata: Identifiable, Equatable {
    public let id: UUID = UUID()
    public var title: String
    public var author: String
    public var totalPages: Int?
    public var bookDescription: String?
    public var coverImageData: Data?
    public var format: BookSourceFormat
    public var fileName: String
    public var isDRMProtected: Bool
    public var appleBooksURL: String?
    
    public init(
        title: String,
        author: String = "",
        totalPages: Int? = nil,
        bookDescription: String? = nil,
        coverImageData: Data? = nil,
        format: BookSourceFormat,
        fileName: String,
        isDRMProtected: Bool = false,
        appleBooksURL: String? = nil
    ) {
        self.title = title
        self.author = author
        self.totalPages = totalPages
        self.bookDescription = bookDescription
        self.coverImageData = coverImageData
        self.format = format
        self.fileName = fileName
        self.isDRMProtected = isDRMProtected
        self.appleBooksURL = appleBooksURL
    }
}

public enum BookImportService {
    
    // MARK: - Primary Parser
    
    /// Parses a document URL (EPUB or PDF) with security scope handling.
    public static func parseDocument(at url: URL) throws -> ExtractedBookMetadata {
        let isSecScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent
        
        switch fileExtension {
        case "pdf":
            return try parsePDF(at: url, fileName: fileName)
        case "epub":
            return try parseEPUB(at: url, fileName: fileName)
        default:
            throw BookImportError.unsupportedFormat(fileExtension.isEmpty ? "unknown" : fileExtension)
        }
    }
    
    // MARK: - PDF Parser
    
    private static func parsePDF(at url: URL, fileName: String) throws -> ExtractedBookMetadata {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw BookImportError.corruptedFile("The PDF document could not be loaded.")
        }
        
        let attributes = pdfDocument.documentAttributes ?? [:]
        
        // Title extraction with clean fallback
        var title = (attributes[PDFDocumentAttribute.titleAttribute] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if title.isEmpty {
            title = sanitizeFileNameAsTitle(fileName)
        }
        
        let author = (attributes[PDFDocumentAttribute.authorAttribute] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let description = (attributes[PDFDocumentAttribute.subjectAttribute] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageCount = pdfDocument.pageCount > 0 ? pdfDocument.pageCount : nil
        
        // Extract first page as cover thumbnail
        var coverData: Data? = nil
        if let firstPage = pdfDocument.page(at: 0) {
            let thumbSize = CGSize(width: 320, height: 460)
            let thumb = firstPage.thumbnail(of: thumbSize, for: .cropBox)
            #if canImport(UIKit)
            coverData = thumb.jpegData(compressionQuality: 0.8)
            #elseif canImport(AppKit)
            if let tiff = thumb.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff) {
                coverData = bitmap.representation(using: .jpeg, properties: [:])
            }
            #endif
        }
        
        return ExtractedBookMetadata(
            title: title,
            author: author,
            totalPages: pageCount,
            bookDescription: description,
            coverImageData: coverData,
            format: .pdf,
            fileName: fileName,
            isDRMProtected: pdfDocument.isEncrypted
        )
    }
    
    // MARK: - EPUB Parser (ZIP Container + OPF XML)
    
    private static func parseEPUB(at url: URL, fileName: String) throws -> ExtractedBookMetadata {
        guard let fileData = try? Data(contentsOf: url) else {
            throw BookImportError.unreadableFile
        }
        
        return try parseEPUBData(fileData, fileName: fileName)
    }
    
    /// Parses raw EPUB binary data. Public for pure unit testability.
    public static func parseEPUBData(_ data: Data, fileName: String) throws -> ExtractedBookMetadata {
        let entries = parseZipEntries(data: data)
        guard !entries.isEmpty else {
            throw BookImportError.corruptedFile("Not a valid EPUB ZIP archive.")
        }
        
        // 1. Check for DRM indicators
        let hasEncryption = entries.contains(where: {
            $0.fileName.contains("encryption.xml") || $0.fileName.contains("rights.xml")
        })
        
        // 2. Find OPF package document
        var opfXML: String? = nil
        
        // Look for .opf entry
        if let opfEntry = entries.first(where: { $0.fileName.lowercased().hasSuffix(".opf") }) {
            if let decompressed = extractEntryData(entry: opfEntry, from: data) {
                opfXML = String(data: decompressed, encoding: .utf8) ?? String(data: decompressed, encoding: .isoLatin1)
            }
        }
        
        // 3. Extract metadata from OPF or fallback
        var title = ""
        var author = ""
        var description: String? = nil
        
        if let xml = opfXML {
            let tags = parseXMLTags(xml: xml)
            title = tags.title ?? ""
            author = tags.author ?? ""
            description = tags.description
        }
        
        if title.isEmpty {
            title = sanitizeFileNameAsTitle(fileName)
        }
        
        return ExtractedBookMetadata(
            title: title,
            author: author,
            totalPages: nil, // EPUBs are reflowable; readers track progress or adjust pages
            bookDescription: description,
            coverImageData: nil,
            format: .epub,
            fileName: fileName,
            isDRMProtected: hasEncryption
        )
    }
    
    // MARK: - Duplicate Detection
    
    /// Checks whether an item with a matching title and author already exists in a given collection.
    public static func findDuplicate<T>(
        title: String,
        author: String = "",
        in items: [T],
        titleOf: (T) -> String,
        authorOf: (T) -> String
    ) -> T? {
        let normNewTitle = normalizeString(title)
        let normNewAuthor = normalizeString(author)
        guard !normNewTitle.isEmpty else { return nil }
        
        for item in items {
            let normBookTitle = normalizeString(titleOf(item))
            let normBookAuthor = normalizeString(authorOf(item))
            
            // Exact title match
            if normBookTitle == normNewTitle {
                // If authors are provided and match, or either is blank
                if normNewAuthor.isEmpty || normBookAuthor.isEmpty || normNewAuthor == normBookAuthor {
                    return item
                }
            }
        }
        
        return nil
    }
    
    /// Convenience duplicate detection for BookDTO collections.
    public static func findDuplicate(
        title: String,
        author: String = "",
        in existingBooks: [BookDTO]
    ) -> BookDTO? {
        findDuplicate(title: title, author: author, in: existingBooks, titleOf: { $0.title }, authorOf: { $0.author })
    }
    
    // MARK: - Helpers & ZIP / XML Parsing
    
    public static func normalizeString(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    public static func sanitizeFileNameAsTitle(_ fileName: String) -> String {
        let nameWithoutExt = (fileName as NSString).deletingPathExtension
        return nameWithoutExt
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public static func parseXMLTags(xml: String) -> (title: String?, author: String?, description: String?) {
        func extract(tag: String) -> String? {
            let pattern = "<\(tag)[^>]*>([^<]+)</\(tag)>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
                return nil
            }
            let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
            if let match = regex.firstMatch(in: xml, options: [], range: range),
               let tagRange = Range(match.range(at: 1), in: xml) {
                return String(xml[tagRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }
        
        let title = extract(tag: "dc:title") ?? extract(tag: "title")
        let author = extract(tag: "dc:creator") ?? extract(tag: "author")
        let desc = extract(tag: "dc:description") ?? extract(tag: "description")
        
        return (title, author, desc)
    }
    
    public struct ZipEntryHeader {
        public let fileName: String
        public let compressionMethod: UInt16
        public let compressedSize: Int
        public let uncompressedSize: Int
        public let dataOffset: Int
    }
    
    public static func parseZipEntries(data: Data) -> [ZipEntryHeader] {
        var entries: [ZipEntryHeader] = []
        var offset = 0
        let totalCount = data.count
        
        data.withUnsafeBytes { rawBuffer in
            guard let bytes = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            
            while offset + 30 <= totalCount {
                // Check local file header signature 0x04034b50 (PK\003\004)
                let sig = UInt32(bytes[offset]) |
                          (UInt32(bytes[offset + 1]) << 8) |
                          (UInt32(bytes[offset + 2]) << 16) |
                          (UInt32(bytes[offset + 3]) << 24)
                
                guard sig == 0x04034b50 else { break }
                
                let method = UInt16(bytes[offset + 8]) | (UInt16(bytes[offset + 9]) << 8)
                let compSize = Int(UInt32(bytes[offset + 18]) |
                                   (UInt32(bytes[offset + 19]) << 8) |
                                   (UInt32(bytes[offset + 20]) << 16) |
                                   (UInt32(bytes[offset + 21]) << 24))
                let uncompSize = Int(UInt32(bytes[offset + 22]) |
                                     (UInt32(bytes[offset + 23]) << 8) |
                                     (UInt32(bytes[offset + 24]) << 16) |
                                     (UInt32(bytes[offset + 25]) << 24))
                let nameLen = Int(UInt16(bytes[offset + 26]) | (UInt16(bytes[offset + 27]) << 8))
                let extraLen = Int(UInt16(bytes[offset + 28]) | (UInt16(bytes[offset + 29]) << 8))
                
                let nameOffset = offset + 30
                guard nameOffset + nameLen <= totalCount else { break }
                
                let nameData = Data(bytes: bytes.advanced(by: nameOffset), count: nameLen)
                let fileName = String(data: nameData, encoding: .utf8) ?? ""
                
                let dataStart = nameOffset + nameLen + extraLen
                entries.append(
                    ZipEntryHeader(
                        fileName: fileName,
                        compressionMethod: method,
                        compressedSize: compSize,
                        uncompressedSize: uncompSize,
                        dataOffset: dataStart
                    )
                )
                
                offset = dataStart + compSize
            }
        }
        
        return entries
    }
    
    public static func extractEntryData(entry: ZipEntryHeader, from archive: Data) -> Data? {
        guard entry.dataOffset + entry.compressedSize <= archive.count else { return nil }
        let slice = archive.subdata(in: entry.dataOffset ..< (entry.dataOffset + entry.compressedSize))
        
        if entry.compressionMethod == 0 {
            // Stored (uncompressed)
            return slice
        } else if entry.compressionMethod == 8 {
            // Raw deflate
            return decompressRawDeflate(data: slice, uncompressedSize: entry.uncompressedSize)
        }
        
        return nil
    }
    
    private static func decompressRawDeflate(data: Data, uncompressedSize: Int) -> Data? {
        guard uncompressedSize > 0 else { return Data() }
        var stream = z_stream()
        
        // -MAX_WBITS instructs zlib to inflate raw deflate streams without zlib headers
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }
        
        var output = Data(count: uncompressedSize)
        let status = output.withUnsafeMutableBytes { outBuf -> Int32 in
            data.withUnsafeBytes { inBuf -> Int32 in
                stream.next_in = UnsafeMutablePointer(mutating: inBuf.baseAddress?.assumingMemoryBound(to: Bytef.self))
                stream.avail_in = uInt(data.count)
                stream.next_out = outBuf.baseAddress?.assumingMemoryBound(to: Bytef.self)
                stream.avail_out = uInt(uncompressedSize)
                return inflate(&stream, Z_FINISH)
            }
        }
        
        guard status == Z_STREAM_END || status == Z_OK else {
            return nil
        }
        output.count = Int(stream.total_out)
        return output
    }
}
