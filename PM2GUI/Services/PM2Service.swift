//
//  PM2Service.swift
//  PM2GUI
//
//  Created by Dinindu Wanniarachchi on 2025-12-18.
//

import Foundation

enum PM2Error: LocalizedError {
    case pm2NotInstalled
    case commandFailed(String)
    case invalidOutput
    case permissionDenied
    case processNotFound

    var errorDescription: String? {
        switch self {
        case .pm2NotInstalled:
            return "PM2 is not installed or not found in PATH. Please install PM2 using 'npm install -g pm2'."
        case .commandFailed(let message):
            return "PM2 command failed: \(message)"
        case .invalidOutput:
            return "Failed to parse PM2 output. The response format may be invalid."
        case .permissionDenied:
            return "Permission denied. The app may need additional permissions to execute PM2 commands."
        case .processNotFound:
            return "Process not found in PM2."
        }
    }
}

class PM2Service {
    static let shared = PM2Service()
    private let logger = Logger.shared
    private var pm2Path: String?
    
    // Configurable timeout - increase this if you're experiencing timeout issues
    var commandTimeout: TimeInterval = 30.0

    private init() {
        logger.log("PM2Service initialized")
        logger.log("Current user: \(NSUserName())")
        logger.log("Home directory: \(FileManager.default.homeDirectoryForCurrentUser.path)")
        logger.log("Current PATH: \(ProcessInfo.processInfo.environment["PATH"] ?? "NOT SET")")
        
        pm2Path = findPM2Path()
        if let path = pm2Path {
            logger.log("Found PM2 at: \(path)")
            
            // Check if it's executable
            let isExecutable = FileManager.default.isExecutableFile(atPath: path)
            logger.log("PM2 is executable: \(isExecutable)")
        } else {
            logger.log("PM2 not found in common paths", level: .error)
        }
    }
    
    // MARK: - PM2 Path Discovery
    
    private func findPM2Path() -> String? {
        // First try using 'which pm2' to find PM2 in the user's PATH
        if let whichPath = findCommandPath(command: "pm2") {
            return whichPath
        }
        
        // Fallback to common PM2 installation paths
        let commonPaths = [
            "/opt/homebrew/bin/pm2",      // Homebrew Apple Silicon
            "/usr/local/bin/pm2",          // Homebrew Intel
            "/usr/bin/pm2",                // System installation
        ]
        
        // Check common paths
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Check NVM paths
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let nvmVersionsPath = "\(homeDir)/.nvm/versions/node"
        if let nvmVersions = try? FileManager.default.contentsOfDirectory(atPath: nvmVersionsPath) {
            for version in nvmVersions.sorted().reversed() { // Try newest versions first
                let pm2Path = "\(nvmVersionsPath)/\(version)/bin/pm2"
                if FileManager.default.fileExists(atPath: pm2Path) {
                    return pm2Path
                }
            }
        }
        
        return nil
    }
    
    private func findCommandPath(command: String) -> String? {
        let task = Process()
        let outputPipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]
        task.standardOutput = outputPipe
        task.standardError = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice

        // Use the user's shell environment
        var environment = ProcessInfo.processInfo.environment

        // Build comprehensive PATH including all common Node.js manager locations
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        var shellPaths: [String] = [
            "/opt/homebrew/bin",      // Apple Silicon Homebrew
            "/usr/local/bin",          // Intel Homebrew
            "/usr/bin",
            "/bin",
        ]

        // Dynamically discover NVM versions
        let nvmVersionsPath = "\(homeDir)/.nvm/versions/node"
        if let nvmVersions = try? FileManager.default.contentsOfDirectory(atPath: nvmVersionsPath) {
            let sortedVersions = nvmVersions.sorted { v1, v2 in
                v1.compare(v2, options: .numeric) == .orderedDescending
            }
            for version in sortedVersions {
                shellPaths.insert("\(nvmVersionsPath)/\(version)/bin", at: 0)
            }
        }

        // Check for volta
        let voltaPath = "\(homeDir)/.volta/bin"
        if FileManager.default.fileExists(atPath: voltaPath) {
            shellPaths.insert(voltaPath, at: 0)
        }

        // Prepend common paths to PATH
        if let existingPath = environment["PATH"] {
            environment["PATH"] = shellPaths.joined(separator: ":") + ":" + existingPath
        } else {
            environment["PATH"] = shellPaths.joined(separator: ":")
        }

        task.environment = environment

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !output.isEmpty {
                    logger.log("Found \(command) via which at: \(output)")
                    return output
                }
            }
        } catch {
            logger.log("Failed to run which \(command): \(error.localizedDescription)")
        }

        return nil
    }

    // MARK: - Process Listing

    func listProcesses() async throws -> [PM2Process] {
        let output = try await executeCommand(arguments: ["jlist"])

        guard !output.isEmpty else {
            logger.log("Empty output from PM2 jlist, returning empty array")
            return []
        }

        let decoder = JSONDecoder()
        do {
            let processes = try decoder.decode([PM2Process].self, from: Data(output.utf8))
            logger.log("Successfully parsed \(processes.count) processes")
            return processes
        } catch {
            // Log detailed error for debugging
            logger.log("PM2 Parsing Error: \(error)", level: .error)
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    logger.log("Key '\(key.stringValue)' not found: \(context.debugDescription)", level: .error)
                case .typeMismatch(let type, let context):
                    logger.log("Type mismatch for type \(type): \(context.debugDescription)", level: .error)
                case .valueNotFound(let type, let context):
                    logger.log("Value not found for type \(type): \(context.debugDescription)", level: .error)
                case .dataCorrupted(let context):
                    logger.log("Data corrupted: \(context.debugDescription)", level: .error)
                @unknown default:
                    logger.log("Unknown decoding error", level: .error)
                }
            }
            logger.log("PM2 Output: \(output)", level: .error)
            throw PM2Error.invalidOutput
        }
    }

    // MARK: - Process Actions

    func startProcess(id: Int) async throws {
        _ = try await executeCommand(arguments: ["start", String(id)])
    }

    func stopProcess(id: Int) async throws {
        _ = try await executeCommand(arguments: ["stop", String(id)])
    }

    func restartProcess(id: Int) async throws {
        _ = try await executeCommand(arguments: ["restart", String(id)])
    }

    func deleteProcess(id: Int) async throws {
        _ = try await executeCommand(arguments: ["delete", String(id)])
    }

    // MARK: - Process Details

    func describeProcess(id: Int) async throws -> PM2ProcessDetail {
        let output = try await executeCommand(arguments: ["describe", String(id)])

        guard !output.isEmpty else {
            throw PM2Error.processNotFound
        }

        let decoder = JSONDecoder()
        do {
            let processes = try decoder.decode([PM2Process].self, from: Data(output.utf8))
            guard let process = processes.first else {
                throw PM2Error.processNotFound
            }
            return PM2ProcessDetail(process: process)
        } catch {
            throw PM2Error.invalidOutput
        }
    }

    // MARK: - Logs

    func fetchLogs(id: Int, lines: Int = 100) async throws -> (stdout: String, stderr: String) {
        let output = try await executeCommand(arguments: ["logs", String(id), "--lines", String(lines), "--nostream", "--raw"])

        // Parse the output to separate stdout and stderr
        // PM2 logs format can vary, so we'll return the combined output for now
        return (stdout: output, stderr: "")
    }

    // MARK: - Health Check

    func checkPM2Installation() async throws -> Bool {
        do {
            let version = try await executeCommand(arguments: ["--version"])
            logger.log("PM2 version check succeeded: \(version)")
            return true
        } catch {
            logger.log("PM2 version check failed: \(error.localizedDescription)", level: .error)
            return false
        }
    }
    
    // MARK: - Diagnostics
    
    func getDiagnosticInfo() async -> String {
        var info = "=== PM2 Service Diagnostics ===\n\n"
        
        // PM2 Path
        if let path = pm2Path {
            info += "PM2 Path: \(path)\n"
            info += "PM2 Exists: \(FileManager.default.fileExists(atPath: path))\n"
        } else {
            info += "PM2 Path: NOT FOUND\n"
        }
        
        info += "\n"
        
        // Environment
        info += "Environment PATH: \(ProcessInfo.processInfo.environment["PATH"] ?? "NOT SET")\n\n"
        
        // Home directory
        info += "Home Directory: \(FileManager.default.homeDirectoryForCurrentUser.path)\n\n"
        
        // Try to check PM2 version
        do {
            let version = try await executeCommand(arguments: ["--version"])
            info += "PM2 Version: \(version)\n"
        } catch {
            info += "PM2 Version Check Failed: \(error.localizedDescription)\n"
        }
        
        info += "\n"
        
        // Try to list processes
        do {
            let output = try await executeCommand(arguments: ["jlist"])
            info += "PM2 jlist output length: \(output.count) bytes\n"
            info += "PM2 jlist output:\n\(output)\n"
        } catch {
            info += "PM2 jlist Failed: \(error.localizedDescription)\n"
        }
        
        return info
    }

    // MARK: - Private Helper Methods

    private func executeCommand(arguments: [String]) async throws -> String {
        guard let pm2Path = pm2Path else {
            logger.log("PM2 path not found")
            throw PM2Error.pm2NotInstalled
        }

        let commandString = "\(pm2Path) " + arguments.joined(separator: " ")
        logger.log("Executing command: \(commandString)")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PM2Error.commandFailed("Service deallocated"))
                    return
                }

                self.logger.log("Started background execution for: \(commandString)")

                let task = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                var hasResumed = false
                let lock = NSLock()

                // Variables to collect output asynchronously
                var outputData = Data()
                var errorData = Data()
                let outputLock = NSLock()

                // Set up the process
                task.executableURL = URL(fileURLWithPath: pm2Path)
                task.arguments = arguments
                task.standardOutput = outputPipe
                task.standardError = errorPipe
                task.standardInput = FileHandle.nullDevice

                // Set up environment
                var environment = ProcessInfo.processInfo.environment
                let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

                if environment["PM2_HOME"] == nil {
                    environment["PM2_HOME"] = "\(homeDir)/.pm2"
                }
                if environment["HOME"] == nil {
                    environment["HOME"] = homeDir
                }

                // Build comprehensive PATH for Node.js
                var nodePaths: [String] = [
                    "/opt/homebrew/bin",
                    "/usr/local/bin",
                    "/usr/bin"
                ]

                let nvmVersionsPath = "\(homeDir)/.nvm/versions/node"
                if let nvmVersions = try? FileManager.default.contentsOfDirectory(atPath: nvmVersionsPath) {
                    let sortedVersions = nvmVersions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
                    for version in sortedVersions {
                        let binPath = "\(nvmVersionsPath)/\(version)/bin"
                        if FileManager.default.fileExists(atPath: binPath) {
                            nodePaths.insert(binPath, at: 0)
                        }
                    }
                }

                let voltaPath = "\(homeDir)/.volta/bin"
                if FileManager.default.fileExists(atPath: voltaPath) {
                    nodePaths.insert(voltaPath, at: 0)
                }

                if let existingPath = environment["PATH"] {
                    environment["PATH"] = nodePaths.joined(separator: ":") + ":" + existingPath
                } else {
                    environment["PATH"] = nodePaths.joined(separator: ":")
                }

                task.environment = environment

                // CRITICAL: Set up async reading BEFORE starting the process
                // This prevents the pipe buffer from filling up and causing deadlock
                let outputHandle = outputPipe.fileHandleForReading
                let errorHandle = errorPipe.fileHandleForReading

                // Read output asynchronously to prevent deadlock
                outputHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        outputLock.lock()
                        outputData.append(data)
                        outputLock.unlock()
                    }
                }

                errorHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty {
                        outputLock.lock()
                        errorData.append(data)
                        outputLock.unlock()
                    }
                }

                // Set termination handler
                task.terminationHandler = { [weak self] process in
                    // Give a small delay for final output to be read
                    Thread.sleep(forTimeInterval: 0.1)

                    // Clean up handlers
                    outputHandle.readabilityHandler = nil
                    errorHandle.readabilityHandler = nil

                    // Read any remaining data
                    outputLock.lock()
                    let remainingOutput = outputHandle.readDataToEndOfFile()
                    let remainingError = errorHandle.readDataToEndOfFile()
                    outputData.append(remainingOutput)
                    errorData.append(remainingError)
                    outputLock.unlock()

                    lock.lock()
                    defer { lock.unlock() }

                    guard !hasResumed else {
                        self?.logger.log("Already resumed, skipping termination handler")
                        return
                    }
                    hasResumed = true

                    outputLock.lock()
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    outputLock.unlock()

                    self?.logger.log("Task exited with status: \(process.terminationStatus)")
                    self?.logger.log("Command output length: \(output.count) bytes")

                    if !errorOutput.isEmpty {
                        self?.logger.log("Command error output: \(errorOutput)")
                    }

                    if process.terminationStatus == 0 {
                        self?.logger.log("Command succeeded: \(commandString)")
                        continuation.resume(returning: output)
                    } else if process.terminationStatus == 15 {
                        self?.logger.log("Command terminated (SIGTERM)", level: .warning)
                        continuation.resume(throwing: PM2Error.commandFailed("Command timed out"))
                    } else {
                        self?.logger.log("Command failed with status \(process.terminationStatus)", level: .error)
                        if errorOutput.contains("command not found") || errorOutput.contains("pm2: not found") {
                            continuation.resume(throwing: PM2Error.pm2NotInstalled)
                        } else if errorOutput.contains("permission denied") {
                            continuation.resume(throwing: PM2Error.permissionDenied)
                        } else {
                            continuation.resume(throwing: PM2Error.commandFailed(errorOutput.isEmpty ? "Exit code: \(process.terminationStatus)" : errorOutput))
                        }
                    }
                }

                do {
                    self.logger.log("About to run task: \(commandString)")
                    try task.run()
                    self.logger.log("Task started with PID: \(task.processIdentifier)")

                    // Set up timeout
                    let timeoutSeconds = self.commandTimeout
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
                        lock.lock()
                        defer { lock.unlock() }

                        if !hasResumed && task.isRunning {
                            self?.logger.log("Command timed out after \(timeoutSeconds) seconds, terminating...", level: .warning)
                            hasResumed = true
                            outputHandle.readabilityHandler = nil
                            errorHandle.readabilityHandler = nil
                            task.terminate()
                            continuation.resume(throwing: PM2Error.commandFailed("Command timed out after \(timeoutSeconds) seconds"))
                        }
                    }

                } catch {
                    self.logger.logError("Failed to run task: \(commandString)", error: error)
                    outputHandle.readabilityHandler = nil
                    errorHandle.readabilityHandler = nil

                    lock.lock()
                    defer { lock.unlock() }

                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(throwing: PM2Error.pm2NotInstalled)
                }
            }
        }
    }
}
