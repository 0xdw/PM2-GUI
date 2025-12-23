//
//  Logger.swift
//  PM2GUI
//
//  Created by Dinindu Wanniarachchi on 2025-12-18.
//

import Foundation

class Logger {
    static let shared = Logger()

    // Directive to enable/disable logfile writing
    static var isFileLoggingEnabled: Bool = false

    private let logFile: URL
    private let fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.pm2gui.logger", qos: .utility)

    private init() {
        // Get the directory where the app is located
        let appPath = Bundle.main.bundlePath
        let appDirectory = (appPath as NSString).deletingLastPathComponent

        // Create log file path in the same directory as the app
        logFile = URL(fileURLWithPath: appDirectory).appendingPathComponent("PM2GUI-Debug.log")

        // Create or open the log file
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil, attributes: nil)
        }

        // Open file handle for appending
        fileHandle = try? FileHandle(forWritingTo: logFile)
        fileHandle?.seekToEndOfFile()

        // Log startup
        log("=== PM2 GUI Started ===")
        log("Log file: \(logFile.path)")
        log("App path: \(appPath)")
        log("Working directory: \(FileManager.default.currentDirectoryPath)")
    }

    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let timestamp = ISO8601DateFormatter().string(from: Date())
            let fileName = (file as NSString).lastPathComponent
            let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line) \(function)] \(message)\n"

            // Print to console
            print(logMessage, terminator: "")

            // Write to file only if logging is enabled
            if Logger.isFileLoggingEnabled {
                if let data = logMessage.data(using: .utf8) {
                    self.fileHandle?.write(data)

                    // Force sync to disk
                    if level == .error || level == .critical {
                        self.fileHandle?.synchronizeFile()
                    }
                }
            }
        }
    }

    func logError(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " - Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, file: file, function: function, line: line)
    }

    func flush() {
        guard Logger.isFileLoggingEnabled else { return }
        queue.sync {
            fileHandle?.synchronizeFile()
        }
    }

    deinit {
        log("=== PM2 GUI Stopped ===")
        fileHandle?.synchronizeFile()
        fileHandle?.closeFile()
    }
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}
