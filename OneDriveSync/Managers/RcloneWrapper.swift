//
//  RcloneWrapper.swift
//  OneDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import Foundation

enum RcloneError: LocalizedError {
    case notInstalled
    case configurationFailed(String)
    case syncFailed(String)
    case invalidRemote(String)
    
    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "rclone is not installed. Please install it via Homebrew: brew install rclone"
        case .configurationFailed(let message):
            return "Configuration failed: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .invalidRemote(let name):
            return "Invalid remote: \(name)"
        }
    }
}

struct RcloneRemote: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let type: String
    
    var displayName: String {
        "\(name) (\(type))"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(type)
    }
    
    static func == (lhs: RcloneRemote, rhs: RcloneRemote) -> Bool {
        lhs.name == rhs.name && lhs.type == rhs.type
    }
}

actor RcloneWrapper {
    private struct ConfigFlowResponse: Decodable {
        let state: String
        let option: ConfigOption?
        let error: String
        let result: String
        
        enum CodingKeys: String, CodingKey {
            case state = "State"
            case option = "Option"
            case error = "Error"
            case result = "Result"
        }
        
        static let completed = ConfigFlowResponse(state: "", option: nil, error: "", result: "")
        
        init(state: String, option: ConfigOption?, error: String, result: String) {
            self.state = state
            self.option = option
            self.error = error
            self.result = result
        }
    }
    
    private struct ConfigOption: Decodable {
        let name: String
        let required: Bool
        let type: String
        let defaultStr: String
        let valueStr: String
        let examples: [ConfigOptionExample]?
        
        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case required = "Required"
            case type = "Type"
            case defaultStr = "DefaultStr"
            case valueStr = "ValueStr"
            case examples = "Examples"
        }
    }
    
    private struct ConfigOptionExample: Decodable {
        let value: String
        
        enum CodingKeys: String, CodingKey {
            case value = "Value"
        }
    }
    
    private let rclonePath: String
    private let runner = ProcessRunner.shared
    
    init(rclonePath: String = AppSettings.defaultRclonePath) {
        self.rclonePath = rclonePath
    }
    
    /// Cancel any currently running sync operation
    func cancelCurrentOperation() async {
        await runner.terminateCurrentProcess()
    }
    
    // MARK: - Installation Check
    
    func isInstalled() async -> Bool {
        do {
            let result = try await runner.run(rclonePath, arguments: ["version"])
            return result.isSuccess
        } catch {
            return false
        }
    }
    
    func version() async throws -> String {
        let result = try await runner.run(rclonePath, arguments: ["version"])
        guard result.isSuccess else {
            throw RcloneError.notInstalled
        }
        // Extract first line (e.g., "rclone v1.65.0")
        return result.stdout.components(separatedBy: "\n").first ?? result.stdout
    }
    
    // MARK: - Remote Management
    
    func listRemotes() async throws -> [RcloneRemote] {
        let result = try await runner.run(rclonePath, arguments: ["listremotes", "--long"])
        guard result.isSuccess else {
            throw RcloneError.configurationFailed(result.stderr)
        }
        
        var remotes: [RcloneRemote] = []
        let lines = result.stdout.components(separatedBy: "\n")
        
        for line in lines where !line.isEmpty {
            // Format: "remotename: type"
            let parts = line.components(separatedBy: ":")
            if parts.count >= 2 {
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                let type = parts[1].trimmingCharacters(in: .whitespaces)
                remotes.append(RcloneRemote(name: name, type: type))
            }
        }
        
        return remotes
    }
    
    func listOneDriveRemotes() async throws -> [RcloneRemote] {
        let allRemotes = try await listRemotes()
        return allRemotes.filter { $0.type == "onedrive" }
    }
    
    /// Creates a OneDrive remote using rclone's non-interactive config flow.
    /// This automatically opens a browser for Microsoft OAuth and accepts defaults
    /// for post-auth backend questions.
    func configureNewOneDrive(name: String) async throws {
        let remoteName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remoteName.isEmpty else {
            throw RcloneError.configurationFailed("Remote name cannot be empty")
        }
        
        let existingNames = Set(try await listRemotes().map(\.name))
        guard !existingNames.contains(remoteName) else {
            throw RcloneError.configurationFailed("Remote '\(remoteName)' already exists")
        }
        
        var shouldCleanup = false
        
        do {
            let createResult = try await runner.run(
                rclonePath,
                arguments: [
                    "config", "create", remoteName, "onedrive",
                    "region", "global",
                    "--non-interactive"
                ]
            )
            guard createResult.isSuccess else {
                throw RcloneError.configurationFailed(createResult.stderr)
            }
            
            shouldCleanup = true
            var response = try decodeConfigFlowResponse(from: createResult.stdout)
            var safetyCounter = 0
            
            while !response.state.isEmpty {
                safetyCounter += 1
                if safetyCounter > 30 {
                    throw RcloneError.configurationFailed("OneDrive setup exceeded expected number of configuration steps")
                }
                
                if !response.error.isEmpty, response.option == nil {
                    throw RcloneError.configurationFailed(response.error)
                }
                
                guard let option = response.option else {
                    throw RcloneError.configurationFailed("Missing config prompt for state '\(response.state)'")
                }
                
                let answer = try automaticAnswer(for: option)
                let continueResult = try await runner.run(
                    rclonePath,
                    arguments: [
                        "config", "update", remoteName,
                        "--continue",
                        "--non-interactive",
                        "--state", response.state,
                        "--result", answer
                    ]
                )
                
                guard continueResult.isSuccess else {
                    throw RcloneError.configurationFailed(continueResult.stderr)
                }
                
                response = try decodeConfigFlowResponse(from: continueResult.stdout)
            }
            
            if !response.error.isEmpty {
                throw RcloneError.configurationFailed(response.error)
            }
            
            let verifyRemotes = try await listOneDriveRemotes()
            guard verifyRemotes.contains(where: { $0.name == remoteName }) else {
                throw RcloneError.configurationFailed("OneDrive remote '\(remoteName)' was not created")
            }
            
            shouldCleanup = false
        } catch {
            if shouldCleanup {
                _ = try? await runner.run(rclonePath, arguments: ["config", "delete", remoteName])
            }
            throw error
        }
    }
    
    /// Opens Terminal to run interactive rclone config
    func openInteractiveConfig() async throws {
        let script = """
        tell application "Terminal"
            activate
            do script "\(rclonePath) config"
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        try process.run()
        process.waitUntilExit()
    }
    
    private func decodeConfigFlowResponse(from output: String) throws -> ConfigFlowResponse {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .completed
        }
        
        let jsonString: String
        if trimmed.first == "{", trimmed.last == "}" {
            jsonString = trimmed
        } else if let start = trimmed.firstIndex(of: "{"),
                  let end = trimmed.lastIndex(of: "}"),
                  start < end {
            jsonString = String(trimmed[start...end])
        } else {
            throw RcloneError.configurationFailed("Unexpected config response: \(trimmed)")
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw RcloneError.configurationFailed("Invalid config response encoding")
        }
        
        do {
            return try JSONDecoder().decode(ConfigFlowResponse.self, from: data)
        } catch {
            throw RcloneError.configurationFailed("Unexpected config response: \(jsonString)")
        }
    }
    
    private func automaticAnswer(for option: ConfigOption) throws -> String {
        switch option.name {
        case "config_is_local":
            return "true"
        case "config_type":
            return "onedrive"
        case "config_token":
            throw RcloneError.configurationFailed(
                "Browser authentication did not complete. Please retry and finish Microsoft login in your browser."
            )
        default:
            if !option.defaultStr.isEmpty {
                return option.defaultStr
            }
            if !option.valueStr.isEmpty {
                return option.valueStr
            }
            if let firstExample = option.examples?.first?.value, !firstExample.isEmpty {
                return firstExample
            }
            if option.type == "bool" {
                return "true"
            }
            if option.required {
                throw RcloneError.configurationFailed("No default answer available for required option '\(option.name)'")
            }
            return ""
        }
    }
    
    private func configFilePath() async throws -> String {
        let result = try await runner.run(rclonePath, arguments: ["config", "file"])
        guard result.isSuccess else {
            throw RcloneError.configurationFailed("Failed to locate rclone config file: \(result.stderr)")
        }
        
        let lines = result.stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard let path = lines.last else {
            throw RcloneError.configurationFailed("Unable to parse rclone config file path")
        }
        
        return path
    }
    
    private func renamedConfigContent(
        from content: String,
        oldName: String,
        newName: String
    ) throws -> String {
        let newline = content.contains("\r\n") ? "\r\n" : "\n"
        var lines = content.components(separatedBy: .newlines)
        var foundOld = false
        
        for idx in lines.indices {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("["),
                  trimmed.hasSuffix("]"),
                  trimmed.count >= 2 else { continue }
            
            let sectionName = String(trimmed.dropFirst().dropLast())
            if sectionName == newName {
                throw RcloneError.configurationFailed("Remote '\(newName)' already exists")
            }
            
            if sectionName == oldName {
                lines[idx] = "[\(newName)]"
                foundOld = true
            }
        }
        
        guard foundOld else {
            throw RcloneError.invalidRemote(oldName)
        }
        
        var updated = lines.joined(separator: newline)
        if content.hasSuffix("\n") || content.hasSuffix("\r\n") {
            updated += newline
        }
        return updated
    }
    
    /// Rename an existing remote
    func renameRemote(from oldName: String, to newName: String) async throws {
        let oldTrimmed = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTrimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !oldTrimmed.isEmpty, !newTrimmed.isEmpty else {
            throw RcloneError.configurationFailed("Remote name cannot be empty")
        }
        
        guard oldTrimmed != newTrimmed else {
            return
        }
        
        let configPath = try await configFilePath()
        let fileURL = URL(fileURLWithPath: configPath)
        let originalContent = try String(contentsOf: fileURL, encoding: .utf8)
        let updatedContent = try renamedConfigContent(
            from: originalContent,
            oldName: oldTrimmed,
            newName: newTrimmed
        )
        
        do {
            try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw RcloneError.configurationFailed("Failed to update rclone config file: \(error.localizedDescription)")
        }
        
        let verifyResult = try await runner.run(rclonePath, arguments: ["config", "show", newTrimmed])
        guard verifyResult.isSuccess else {
            // Best-effort rollback
            try? originalContent.write(to: fileURL, atomically: true, encoding: .utf8)
            throw RcloneError.configurationFailed("Rename verification failed: \(verifyResult.stderr)")
        }
    }
    
    /// Delete a remote
    func deleteRemote(name: String) async throws {
        let result = try await runner.run(rclonePath, arguments: ["config", "delete", name])
        guard result.isSuccess else {
            throw RcloneError.configurationFailed("Failed to delete remote: \(result.stderr)")
        }
    }
    
    /// Try to retrieve a web URL for a remote path using `rclone link`.
    /// Returns nil when the backend or remote doesn't provide a link.
    func getWebLink(remote: String, path: String) async -> URL? {
        do {
            let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let remotePath = normalizedPath.isEmpty ? "\(remote):" : "\(remote):\(normalizedPath)"
            let result = try await runner.run(rclonePath, arguments: ["link", remotePath])
            guard result.isSuccess else {
                return nil
            }
            
            let urlString = result.stdout
                .components(separatedBy: "\n")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !urlString.isEmpty else { return nil }
            return URL(string: urlString)
        } catch {
            print("Failed to get web link: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Sync Operations
    
    func sync(
        source: String,
        destination: String,
        dryRun: Bool = false,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> SyncResult {
        var args = ["sync", source, destination, "--progress", "--stats-one-line"]
        
        if dryRun {
            args.append("--dry-run")
        }
        
        let startTime = Date()
        
        let result: ProcessResult
        if let progressHandler = onProgress {
            result = try await runner.runWithProgress(rclonePath, arguments: args) { output in
                progressHandler(output)
            }
        } else {
            result = try await runner.run(rclonePath, arguments: args)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        if result.isSuccess {
            return SyncResult(
                success: true,
                filesTransferred: parseFileCount(from: result.stdout),
                bytesTransferred: parseByteCount(from: result.stdout),
                duration: duration,
                error: nil
            )
        } else {
            throw RcloneError.syncFailed(result.stderr)
        }
    }
    
    func copy(
        source: String,
        destination: String,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> SyncResult {
        let args = ["copy", source, destination, "--progress", "--stats-one-line"]
        
        let startTime = Date()
        
        let result: ProcessResult
        if let progressHandler = onProgress {
            result = try await runner.runWithProgress(rclonePath, arguments: args) { output in
                progressHandler(output)
            }
        } else {
            result = try await runner.run(rclonePath, arguments: args)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        if result.isSuccess {
            return SyncResult(
                success: true,
                filesTransferred: parseFileCount(from: result.stdout),
                bytesTransferred: parseByteCount(from: result.stdout),
                duration: duration,
                error: nil
            )
        } else {
            throw RcloneError.syncFailed(result.stderr)
        }
    }
    
    // MARK: - Helpers
    
    private func parseFileCount(from output: String) -> Int {
        // Parse "Transferred: X / Y, 100%" pattern
        let pattern = #"Transferred:\s+(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let range = Range(match.range(at: 1), in: output) {
            return Int(output[range]) ?? 0
        }
        return 0
    }
    
    private func parseByteCount(from output: String) -> Int64 {
        // rclone stats one-line outputs like: "Transferred: 5.459 MiB / 6.622 MiB, 82%, 0 B/s, ETA -"
        // We look for the part before the first "/"
        let pattern = #"Transferred:\s+([\d.]+)\s*(\w+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let valueRange = Range(match.range(at: 1), in: output),
           let unitRange = Range(match.range(at: 2), in: output) {
            
            let valueStr = String(output[valueRange])
            let unitStr = String(output[unitRange]).lowercased()
            
            if let value = Double(valueStr) {
                let multiplier: Double
                switch unitStr {
                case "b": multiplier = 1
                case "k", "kib": multiplier = 1024
                case "m", "mib": multiplier = 1024 * 1024
                case "g", "gib": multiplier = 1024 * 1024 * 1024
                case "t", "tib": multiplier = 1024 * 1024 * 1024 * 1024
                default: multiplier = 1
                }
                return Int64(value * multiplier)
            }
        }
        return 0
    }
}

struct SyncResult {
    let success: Bool
    let filesTransferred: Int
    let bytesTransferred: Int64
    let duration: TimeInterval
    let error: String?
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "\(Int(duration))s"
    }
}
