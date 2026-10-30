//
//  CloudKitSyncService.swift
//  BookStride
//
//  Monitors iCloud CloudKit account status, sync health, and offline transitions.
//  Exposes truthful synchronization state without fake progress indicators.
//

import Foundation
import Combine
#if canImport(CloudKit)
import CloudKit
#endif
#if canImport(Network)
import Network
#endif

public enum CloudKitSyncState: Equatable {
    case available(lastSync: Date?)
    case syncing
    case offline
    case accountNotAvailable
    case restricted
    case error(String)
    
    public var title: String {
        switch self {
        case .available: return "iCloud Sync Active"
        case .syncing: return "Syncing with iCloud..."
        case .offline: return "Offline (Local-First Active)"
        case .accountNotAvailable: return "iCloud Account Signed Out"
        case .restricted: return "iCloud Access Restricted"
        case .error: return "iCloud Sync Issue"
        }
    }
    
    public var description: String {
        switch self {
        case .available(let date):
            if let d = date {
                return "All books, sessions, and journal notes are synced. Last synced: \(Formatters.formatDate(d, style: .dateTime))."
            } else {
                return "CloudKit synchronization is active. All local changes sync automatically."
            }
        case .syncing:
            return "Sending recent reading activity and journal entries to your private iCloud container."
        case .offline:
            return "No internet connection detected. BookStride is fully operational and storing all changes locally."
        case .accountNotAvailable:
            return "Sign in to your Apple Account in System Settings to enable automatic sync between iPad and Mac."
        case .restricted:
            return "iCloud access is restricted by Screen Time or device management policies."
        case .error(let msg):
            return "Unable to connect to iCloud container: \(msg). Data remains safe in local storage."
        }
    }
    
    public var statusBadgeColorHex: String {
        switch self {
        case .available: return "forest"
        case .syncing: return "navy"
        case .offline: return "terracotta"
        case .accountNotAvailable, .restricted: return "slate"
        case .error: return "burgundy"
        }
    }
}

public final class CloudKitSyncService: ObservableObject {
    public static let shared = CloudKitSyncService()
    public static let containerIdentifier = "iCloud.com.amitroy.BookStride"
    private static let lastSyncKey = "BookStride_CloudKit_LastSyncDate"
    
    @Published public private(set) var syncState: CloudKitSyncState = .available(lastSync: nil)
    @Published public private(set) var isNetworkAvailable: Bool = true
    
    #if canImport(Network)
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.amitroy.BookStride.NetworkMonitor")
    #endif
    
    private init() {
        let savedDate = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        self.syncState = .available(lastSync: savedDate)
        setupNetworkMonitoring()
        checkAccountStatus()
    }
    
    // MARK: - Network Status
    
    private func setupNetworkMonitoring() {
        #if canImport(Network)
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isNetworkAvailable = (path.status == .satisfied)
                if !self.isNetworkAvailable {
                    self.syncState = .offline
                } else {
                    self.checkAccountStatus()
                }
            }
        }
        monitor.start(queue: monitorQueue)
        #endif
    }
    
    // MARK: - Account Status Verification
    
    public func checkAccountStatus() {
        #if canImport(CloudKit)
        let container = CKContainer(identifier: Self.containerIdentifier)
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let err = error {
                    // Check if it's network error
                    if !self.isNetworkAvailable {
                        self.syncState = .offline
                    } else {
                        self.syncState = .error(err.localizedDescription)
                    }
                    return
                }
                
                switch status {
                case .available:
                    let savedDate = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
                    self.syncState = .available(lastSync: savedDate)
                case .noAccount:
                    self.syncState = .accountNotAvailable
                case .restricted:
                    self.syncState = .restricted
                case .couldNotDetermine:
                    self.syncState = .error("Could not determine iCloud account status")
                case .temporarilyUnavailable:
                    self.syncState = .error("iCloud service is temporarily unavailable")
                @unknown default:
                    self.syncState = .available(lastSync: nil)
                }
            }
        }
        #else
        self.syncState = .available(lastSync: nil)
        #endif
    }
    
    /// Records a successful sync timestamp.
    public func recordSuccessfulSync(at date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: Self.lastSyncKey)
        self.syncState = .available(lastSync: date)
    }
    
    /// Performs an emergency pre-sync JSON backup of the current database.
    public static func createPreSyncSafetyBackup(books: [BookDTO], sessions: [ReadingSessionDTO], goals: [ReadingGoalDTO], journal: [JournalEntryDTO]) -> URL? {
        let json = DataExportService.exportAllToJSON(
            bookDTOs: books,
            sessionDTOs: sessions,
            goalDTOs: goals,
            journalDTOs: journal
        )
        let filename = "BookStride-PreSync-Backup-\(Int(Date().timeIntervalSince1970)).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try json.data(using: .utf8)?.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }
}

