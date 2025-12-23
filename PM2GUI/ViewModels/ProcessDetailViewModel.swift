//
//  ProcessDetailViewModel.swift
//  PM2GUI
//
//  Created by Dinindu Wanniarachchi on 2025-12-18.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ProcessDetailViewModel: ObservableObject {
    @Published var processDetail: PM2ProcessDetail?
    @Published var stdout: String = ""
    @Published var stderr: String = ""
    @Published var isLoadingLogs = false
    @Published var errorMessage: String?

    private let pm2Service = PM2Service.shared
    let process: PM2Process

    init(process: PM2Process) {
        self.process = process
    }

    func loadProcessDetails() async {
        do {
            let detail = try await pm2Service.describeProcess(id: process.id)
            processDetail = detail
        } catch let error as PM2Error {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load process details."
        }
    }

    func loadLogs(lines: Int = 100) async {
        isLoadingLogs = true
        errorMessage = nil

        do {
            let logs = try await pm2Service.fetchLogs(id: process.id, lines: lines)
            stdout = logs.stdout
            stderr = logs.stderr
        } catch let error as PM2Error {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load logs."
        }

        isLoadingLogs = false
    }
}
