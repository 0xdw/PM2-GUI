//
//  ProcessDetailView.swift
//  PM2GUI
//
//  Created by Dinindu Wanniarachchi on 2025-12-18.
//

import SwiftUI

struct ProcessDetailView: View {
    @StateObject private var viewModel: ProcessDetailViewModel
    @State private var selectedTab = 0
    var onClose: (() -> Void)? = nil

    init(process: PM2Process, onClose: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ProcessDetailViewModel(process: process))
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact header with process name, status, and close button
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.process.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.linearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    HStack(spacing: 6) {
                        GlowingStatusIndicator(
                            color: statusColor(viewModel.process.statusColor),
                            size: 8
                        )
                        Text(viewModel.process.status.capitalized)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
                if let onClose = onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.linearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color(white: 0.1).opacity(0.3),
                                Color(white: 0.05).opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }

            // Content
            if selectedTab == 0 {
                overviewView
            } else {
                logsView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Overview View

    private var overviewView: some View {
        VStack(spacing: 0) {
            // Compact Overview Toolbar with tabs
            HStack(spacing: 16) {
                // Tabs
                Picker("", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Logs").tag(1)
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            GlowingDivider()
                .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                // Basic Information
                LiquidGlassGroupBox(label: "Basic Information") {
                    VStack(alignment: .leading, spacing: 10) {
                        DetailRow(label: "Process ID", value: "\(viewModel.process.id)")
                        DetailRow(label: "PID", value: viewModel.process.pid.map { "\($0)" } ?? "N/A")
                        DetailRow(label: "Status", value: viewModel.process.status)
                        DetailRow(label: "Uptime", value: viewModel.process.uptimeFormatted)
                        DetailRow(label: "Restarts", value: "\(viewModel.process.restartCount)")
                    }
                }

                // Resource Usage
                LiquidGlassGroupBox(label: "Resource Usage") {
                    VStack(alignment: .leading, spacing: 10) {
                        DetailRow(
                            label: "CPU Usage",
                            value: String(format: "%.1f%%", viewModel.process.cpuUsage),
                            valueColor: viewModel.process.cpuUsage > 50 ? .orange : .neonBlue
                        )
                        DetailRow(
                            label: "Memory Usage",
                            value: String(format: "%.2f MB", viewModel.process.memoryUsage),
                            valueColor: .neonPurple
                        )
                    }
                }

                // Execution Details
                if let execPath = viewModel.process.pm2_env.pm_exec_path {
                    LiquidGlassGroupBox(label: "Execution Details") {
                        VStack(alignment: .leading, spacing: 10) {
                            DetailRow(label: "Script Path", value: execPath)
                            if let execMode = viewModel.process.pm2_env.exec_mode {
                                DetailRow(label: "Execution Mode", value: execMode)
                            }
                            if let nodeVersion = viewModel.process.pm2_env.node_version {
                                DetailRow(label: "Node Version", value: nodeVersion)
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red.opacity(0.9))
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                    }
                }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Logs View

    private var logsView: some View {
        VStack(spacing: 0) {
            // Compact Logs Toolbar with tabs and refresh button
            HStack() {
                // Tabs
                Picker("", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Logs").tag(1)
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Spacer()

                // Refresh button
                Button("Refresh") {
                    Task {
                        await viewModel.loadLogs()
                    }
                }
                .neonButton(color: .neonBlue, intensity: 0.8)
                .disabled(viewModel.isLoadingLogs)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            GlowingDivider()
                .padding(.horizontal, 20)

            if viewModel.isLoadingLogs {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.neonBlue)
                    Text("Loading logs...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
            } else if viewModel.stdout.isEmpty && viewModel.stderr.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.linearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    Text("No logs available")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Button("Load Logs") {
                        Task {
                            await viewModel.loadLogs()
                        }
                    }
                    .neonButton(color: .neonBlue, intensity: 1.0)
                    .padding(.top, 8)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !viewModel.stdout.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "terminal.fill")
                                        .foregroundStyle(.linearGradient(
                                            colors: [.neonBlue, .white],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                    Text("STDOUT")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)

                                Text(viewModel.stdout)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85))
                                    .textSelection(.enabled)
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.ultraThinMaterial)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(white: 0.05).opacity(0.4))
                                            }
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                            }
                        }

                        if !viewModel.stderr.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.linearGradient(
                                            colors: [.red, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                    Text("STDERR")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.red.opacity(0.9))
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                                Text(viewModel.stderr)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(.red.opacity(0.9))
                                    .textSelection(.enabled)
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.ultraThinMaterial)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.red.opacity(0.15))
                                            }
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                GlowingDivider()
                    .padding(.horizontal, 20)
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                    Spacer()
                }
                .padding(16)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Rectangle()
                                .fill(Color.red.opacity(0.1))
                        }
                }
            }
        }
        .task {
            await viewModel.loadLogs()
        }
    }

    private func statusColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        default: return .gray
        }
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color?

    init(label: String, value: String, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(valueColor ?? .white.opacity(0.9))
                .textSelection(.enabled)
            Spacer()
        }
    }
}

// MARK: - Liquid Glass Components (ProcessDetailView-specific)

// Note: Most Liquid Glass components are defined in ProcessListView.swift
// Only ProcessDetailView-specific components are defined here

struct LiquidGlassGroupBox<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            content
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.12).opacity(0.4),
                                    Color(white: 0.05).opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
    }
}

#Preview {
    ProcessDetailView(process: PM2Process(
        id: 0,
        name: "test-app",
        pm2_env: PM2Environment(
            status: "online",
            pm_uptime: 1700000000000,
            restart_time: 5,
            exec_mode: "cluster",
            pm_exec_path: "/path/to/app.js",
            created_at: 1700000000000,
            version: "1.0.0",
            node_version: "18.0.0"
        ),
        pid: 1234,
        monit: ProcessMonit(memory: 52428800, cpu: 2.5)
    ))
}
