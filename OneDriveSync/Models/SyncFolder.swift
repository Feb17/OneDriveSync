//
//  SyncFolder.swift
//  OneDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import Foundation

enum SyncStatus: String, Codable {
    case idle
    case syncing
    case success
    case error
}

struct SyncFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var localPath: String
    var remoteName: String      // e.g., "onedrive_personal"
    var remotePath: String      // e.g., "Backups/YAML", "/" for remote root, empty for auto folder name
    var lastSyncDate: Date?
    var lastSyncStatus: SyncStatus
    var isEnabled: Bool
    var lastError: String?
    
    init(
        id: UUID = UUID(),
        localPath: String,
        remoteName: String,
        remotePath: String = "",
        lastSyncDate: Date? = nil,
        lastSyncStatus: SyncStatus = .idle,
        isEnabled: Bool = true,
        lastError: String? = nil
    ) {
        self.id = id
        self.localPath = localPath
        self.remoteName = remoteName
        self.remotePath = remotePath
        self.lastSyncDate = lastSyncDate
        self.lastSyncStatus = lastSyncStatus
        self.isEnabled = isEnabled
        self.lastError = lastError
    }
    
    var displayName: String {
        URL(fileURLWithPath: localPath).lastPathComponent
    }
    
    /// Resolved destination path on remote.
    /// - Empty input means "use local folder name".
    /// - "/" means remote root.
    /// - Any other value is treated as a relative remote path.
    var effectiveRemotePath: String {
        let input = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if input == "/" {
            return ""
        }
        
        let cleaned = input.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !cleaned.isEmpty {
            return cleaned
        }
        
        return URL(fileURLWithPath: localPath).lastPathComponent
    }
    
    var fullRemotePath: String {
        let path = effectiveRemotePath
        if path.isEmpty {
            return "\(remoteName):"
        }
        return "\(remoteName):\(path)"
    }
}
