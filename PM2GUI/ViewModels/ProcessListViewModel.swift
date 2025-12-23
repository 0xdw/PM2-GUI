//
//  ProcessListViewModel.swift
//  PM2GUI
//
//  Created by Dinindu Wanniarachchi on 2025-12-18.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ProcessListViewModel: ObservableObject {
    @Published var processes: [PM2Process] = []
    @Published var filteredProcesses: [PM2Process] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedStatus: String = "all"
    @Published var selectedProcess: PM2Process?
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var alertTitle = ""

    private let pm2Service = PM2Service.shared
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 3.0

    let availableStatuses = ["all", "online", "stopped", "errored", "launching", "stopping"]

    init() {
        Task {
            await checkAndStartAutoRefresh()
        }
    }

    deinit {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Auto Refresh

    private func checkAndStartAutoRefresh() async {
        print("🔍 Checking PM2 installation...")
        // First check if PM2 is installed
        do {
            let isInstalled = try await pm2Service.checkPM2Installation()
            print("📦 PM2 installation check result: \(isInstalled)")
            if isInstalled {
                print("✅ PM2 is installed, starting auto-refresh...")
                startAutoRefresh()
            } else {
                let errorMsg = "PM2 is not installed or not found in PATH. Please install PM2 using 'npm install -g pm2'."
                print("❌ \(errorMsg)")
                errorMessage = errorMsg
            }
        } catch {
            let errorMsg = "Failed to connect to PM2. Please ensure PM2 is installed and accessible."
            print("❌ \(errorMsg)")
            print("❌ Error details: \(error.localizedDescription)")
            errorMessage = errorMsg
        }
    }

    func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshProcesses(showLoading: false)
            }
        }
        Task {
            await refreshProcesses()
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Data Loading

    func refreshProcesses(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil

        do {
            let fetchedProcesses = try await pm2Service.listProcesses()

            // Update all properties together to ensure UI refresh
            processes = fetchedProcesses
            applyFilters()

            // Update the selected process reference if one is selected
            if let currentSelected = selectedProcess {
                selectedProcess = processes.first(where: { $0.id == currentSelected.id })
            }
            
            // Log success
            print("✅ Successfully loaded \(fetchedProcesses.count) processes")
        } catch let error as PM2Error {
            errorMessage = error.errorDescription
            print("❌ PM2Error: \(error.errorDescription ?? "Unknown error")")
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            print("❌ Unexpected error: \(error.localizedDescription)")
        }

        if showLoading {
            isLoading = false
        }
    }

    func checkPM2Installation() async {
        do {
            let isInstalled = try await pm2Service.checkPM2Installation()
            if !isInstalled {
                errorMessage = "PM2 is not installed or not found in PATH."
            }
        } catch {
            errorMessage = "Failed to check PM2 installation."
        }
    }

    // MARK: - Filtering and Search

    func applyFilters() {
        var filtered = processes

        // Apply status filter
        if selectedStatus != "all" {
            filtered = filtered.filter { $0.status.lowercased() == selectedStatus.lowercased() }
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }

        filteredProcesses = filtered
    }

    // MARK: - Process Actions

    func startProcess(_ process: PM2Process) async {
        do {
            try await pm2Service.startProcess(id: process.id)
            showSuccessAlert(title: "Success", message: "Process '\(process.name)' started successfully.")
            await refreshProcesses(showLoading: false)
        } catch let error as PM2Error {
            showErrorAlert(message: error.errorDescription ?? "Failed to start process.")
        } catch {
            showErrorAlert(message: "An unexpected error occurred.")
        }
    }

    func stopProcess(_ process: PM2Process) async {
        do {
            try await pm2Service.stopProcess(id: process.id)
            showSuccessAlert(title: "Success", message: "Process '\(process.name)' stopped successfully.")
            await refreshProcesses(showLoading: false)
        } catch let error as PM2Error {
            showErrorAlert(message: error.errorDescription ?? "Failed to stop process.")
        } catch {
            showErrorAlert(message: "An unexpected error occurred.")
        }
    }

    func restartProcess(_ process: PM2Process) async {
        do {
            try await pm2Service.restartProcess(id: process.id)
            showSuccessAlert(title: "Success", message: "Process '\(process.name)' restarted successfully.")
            await refreshProcesses(showLoading: false)
        } catch let error as PM2Error {
            showErrorAlert(message: error.errorDescription ?? "Failed to restart process.")
        } catch {
            showErrorAlert(message: "An unexpected error occurred.")
        }
    }

    func deleteProcess(_ process: PM2Process) async {
        do {
            try await pm2Service.deleteProcess(id: process.id)
            showSuccessAlert(title: "Success", message: "Process '\(process.name)' deleted successfully.")
            await refreshProcesses(showLoading: false)
        } catch let error as PM2Error {
            showErrorAlert(message: error.errorDescription ?? "Failed to delete process.")
        } catch {
            showErrorAlert(message: "An unexpected error occurred.")
        }
    }

    // MARK: - Alert Helpers

    private func showSuccessAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }

    private func showErrorAlert(message: String) {
        alertTitle = "Error"
        alertMessage = message
        showingAlert = true
    }
}
