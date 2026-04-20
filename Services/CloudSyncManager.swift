//
//  CloudSyncManager.swift
//  FitNotes iOS
//
//  iCloud Drive file-based sync as defined in product_roadmap.md section 3.6
//  Strategy: Option 2 — push the SwiftData store as a .fitnotes file to iCloud Drive.
//  Simpler than CloudKit record-level sync; matches the existing FitNotes backup paradigm.
//
//  On workout save: schedule a background copy to iCloud.
//  On app launch: compare modification dates and prompt if cloud version is newer.
//

import Foundation
import SwiftData

actor CloudSyncManager {

    static let shared = CloudSyncManager()

    // MARK: - iCloud Container

    /// The iCloud ubiquity container URL for backups.
    /// Returns nil if iCloud is not available or the user is not signed in.
    private var iCloudContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
    }

    private let backupFileName = "FitNotes_Backup.fitnotes"

    /// Whether iCloud Drive is available for the current user.
    var isAvailable: Bool { iCloudContainerURL != nil }

    // MARK: - Backup to iCloud

    /// Copies the local SwiftData store to iCloud Drive.
    /// Called after each workout save or manually from Settings.
    func backupToCloud() async throws {
        guard let cloudURL = iCloudContainerURL else {
            throw CloudSyncError.iCloudNotAvailable
        }

        let localURL = AppGroup.containerURL.appendingPathComponent("FitNotes.store")
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw CloudSyncError.localStoreNotFound
        }

        // Ensure the iCloud Documents directory exists
        if !FileManager.default.fileExists(atPath: cloudURL.path) {
            try FileManager.default.createDirectory(at: cloudURL, withIntermediateDirectories: true)
        }

        let destinationURL = cloudURL.appendingPathComponent(backupFileName)

        // Remove existing cloud backup if present, then copy
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: localURL, to: destinationURL)
    }

    /// Creates a timestamped backup in iCloud Drive (for manual "Save Backup" action).
    func createTimestampedBackup() async throws -> URL {
        guard let cloudURL = iCloudContainerURL else {
            throw CloudSyncError.iCloudNotAvailable
        }

        let localURL = AppGroup.containerURL.appendingPathComponent("FitNotes.store")
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw CloudSyncError.localStoreNotFound
        }

        if !FileManager.default.fileExists(atPath: cloudURL.path) {
            try FileManager.default.createDirectory(at: cloudURL, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: .now)
        let fileName = "FitNotes_Backup_\(timestamp).fitnotes"
        let destinationURL = cloudURL.appendingPathComponent(fileName)

        try FileManager.default.copyItem(at: localURL, to: destinationURL)
        return destinationURL
    }

    // MARK: - Restore from iCloud

    /// Checks whether a cloud backup exists and returns its metadata.
    func cloudBackupStatus() async throws -> BackupStatus? {
        guard let cloudURL = iCloudContainerURL else { return nil }

        let backupURL = cloudURL.appendingPathComponent(backupFileName)
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return nil }

        // Ensure the file is downloaded from iCloud
        try startDownloadIfNeeded(backupURL)

        let attributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)
        let modificationDate = attributes[.modificationDate] as? Date ?? .distantPast
        let fileSize = attributes[.size] as? Int64 ?? 0

        return BackupStatus(
            url: backupURL,
            modificationDate: modificationDate,
            fileSize: fileSize
        )
    }

    /// Restores the SwiftData store from the iCloud backup.
    /// **Destructive** — overwrites the local store. The caller must confirm with the user first.
    func restoreFromCloud() async throws {
        guard let cloudURL = iCloudContainerURL else {
            throw CloudSyncError.iCloudNotAvailable
        }

        let sourceURL = cloudURL.appendingPathComponent(backupFileName)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CloudSyncError.cloudBackupNotFound
        }

        // Ensure file is fully downloaded
        try startDownloadIfNeeded(sourceURL)
        try await waitForDownload(sourceURL)

        let localURL = AppGroup.containerURL.appendingPathComponent("FitNotes.store")

        // Remove existing local store
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        // Also remove WAL and SHM files if present
        for suffix in ["-wal", "-shm"] {
            let sidecarURL = localURL.appendingPathExtension(suffix)
            if FileManager.default.fileExists(atPath: sidecarURL.path) {
                try FileManager.default.removeItem(at: sidecarURL)
            }
        }

        try FileManager.default.copyItem(at: sourceURL, to: localURL)
    }

    // MARK: - Conflict Detection

    /// Compares local and cloud modification dates to detect whether the cloud
    /// version is newer. Called on app launch.
    func checkForNewerCloudBackup() async throws -> ConflictResult {
        guard let cloudStatus = try await cloudBackupStatus() else {
            return .noCloudBackup
        }

        let localURL = AppGroup.containerURL.appendingPathComponent("FitNotes.store")
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            return .cloudIsNewer(cloudStatus)
        }

        let localAttributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
        let localModDate = localAttributes[.modificationDate] as? Date ?? .distantPast

        if cloudStatus.modificationDate > localModDate {
            return .cloudIsNewer(cloudStatus)
        } else {
            return .localIsNewer
        }
    }

    // MARK: - List all backups in iCloud

    /// Returns all .fitnotes files in the iCloud Documents directory, sorted newest first.
    func listCloudBackups() async throws -> [BackupStatus] {
        guard let cloudURL = iCloudContainerURL else { return [] }

        guard FileManager.default.fileExists(atPath: cloudURL.path) else { return [] }

        let contents = try FileManager.default.contentsOfDirectory(
            at: cloudURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        return try contents
            .filter { $0.pathExtension == "fitnotes" }
            .map { url in
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                return BackupStatus(
                    url: url,
                    modificationDate: attrs[.modificationDate] as? Date ?? .distantPast,
                    fileSize: attrs[.size] as? Int64 ?? 0
                )
            }
            .sorted { $0.modificationDate > $1.modificationDate }
    }

    // MARK: - iCloud Download Helpers

    private func startDownloadIfNeeded(_ url: URL) throws {
        var isDownloaded = false
        let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        if let status = values.ubiquitousItemDownloadingStatus {
            isDownloaded = (status == .current)
        }

        if !isDownloaded {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }

    private func waitForDownload(_ url: URL, timeout: TimeInterval = 30) async throws {
        let deadline = Date.now.addingTimeInterval(timeout)

        while Date.now < deadline {
            let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if values.ubiquitousItemDownloadingStatus == .current {
                return
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw CloudSyncError.downloadTimeout
    }

    // MARK: - Types

    struct BackupStatus {
        let url: URL
        let modificationDate: Date
        let fileSize: Int64

        var fileSizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    }

    enum ConflictResult {
        case noCloudBackup
        case cloudIsNewer(BackupStatus)
        case localIsNewer
    }

    enum CloudSyncError: LocalizedError {
        case iCloudNotAvailable
        case localStoreNotFound
        case cloudBackupNotFound
        case downloadTimeout

        var errorDescription: String? {
            switch self {
            case .iCloudNotAvailable:
                return "iCloud Drive is not available. Please sign in to iCloud in Settings."
            case .localStoreNotFound:
                return "No local workout data found to back up."
            case .cloudBackupNotFound:
                return "No backup found in iCloud Drive."
            case .downloadTimeout:
                return "Timed out waiting for the iCloud file to download."
            }
        }
    }
}
