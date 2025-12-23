//
//  ProcessListView.swift
//  PM2GUI
//
//  Created by Dinindu Wanniarachchi on 2025-12-18.
//

import SwiftUI
import AppKit

struct ProcessListView: View {
    @StateObject private var viewModel = ProcessListViewModel()
    @State private var showingDeleteConfirmation = false
    @State private var showingStopConfirmation = false
    @State private var processToDelete: PM2Process?
    @State private var processToStop: PM2Process?
    @State private var showingSideDrawer = false
    @State private var selectedProcessSet: Set<Int> = []
    @State private var showingDiagnostics = false
    @State private var diagnosticInfo = ""

    var body: some View {
        mainContent
            .overlay(alignment: .trailing) {
                sideDrawer
            }
            .navigationTitle("PM2 Process Manager")
    }

    private var mainContent: some View {
        ZStack {
            // Deep dark gray + black gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.08),
                    Color(red: 0.02, green: 0.02, blue: 0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar with Liquid Glass styling
                HStack(spacing: 12) {
                    // Search with glass effect
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.linearGradient(
                                colors: [.neonBlue, .neonPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .font(.system(size: 14, weight: .medium))
                        TextField("Search processes", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .onChange(of: viewModel.searchText) { _ in
                                viewModel.applyFilters()
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minWidth: 200)
                    .liquidGlassTextField()

                    // Status Filter with neon styling
                    Picker("Status", selection: $viewModel.selectedStatus) {
                        ForEach(viewModel.availableStatuses, id: \.self) { status in
                            Text(status.capitalized).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .onChange(of: viewModel.selectedStatus) { _ in
                        viewModel.applyFilters()
                    }
                    .neonButton(color: .neonBlue, intensity: 0.6)

                    Spacer()

                    // Diagnostics Button with neon glow
                    Button(action: {
                        Task {
                            diagnosticInfo = await PM2Service.shared.getDiagnosticInfo()
                            showingDiagnostics = true
                        }
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.linearGradient(
                                colors: [.neonBlue, .white],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    }
                    .buttonStyle(.plain)
                    .help("Show Diagnostics")

                    // Refresh Button with neon glow
                    Button(action: {
                        Task {
                            await viewModel.refreshProcesses()
                        }
                    }) {
                        Image(systemName: viewModel.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.linearGradient(
                                colors: [.neonPurple, .white],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                            .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                GlowingDivider()
                    .padding(.horizontal, 20)

                // Process List
                if viewModel.isLoading && viewModel.processes.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.neonBlue)
                        Text("Loading processes...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.linearGradient(
                                colors: [.white.opacity(0.9), .white.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                        Spacer()
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.linearGradient(
                                colors: [.red, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .shadow(color: .red.opacity(0.5), radius: 20, x: 0, y: 10)
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task {
                                await viewModel.refreshProcesses()
                            }
                        }
                        .neonButton(color: .neonBlue, intensity: 1.2)
                        Spacer()
                    }
                    .padding()
                } else if viewModel.filteredProcesses.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "tray.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.linearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                        Text("No processes found")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        // Table without hover effects
                        Table(viewModel.filteredProcesses, selection: $selectedProcessSet) {
                            TableColumn("Name") { process in
                                Text(process.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .width(min: 150)

                            TableColumn("ID") { process in
                                Text("\(process.id)")
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .width(min: 50, max: 80)

                            TableColumn("Status") { process in
                                HStack(spacing: 6) {
                                    GlowingStatusIndicator(
                                        color: statusColor(process.statusColor),
                                        size: 8
                                    )
                                    Text(process.status)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .width(min: 100)

                            TableColumn("CPU") { process in
                                Text(String(format: "%.1f%%", process.cpuUsage))
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundStyle(.linearGradient(
                                        colors: process.cpuUsage > 50 ? [.orange, .red] : [.neonBlue, .white],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            }
                            .width(min: 80)

                            TableColumn("Memory") { process in
                                Text(String(format: "%.0f MB", process.memoryUsage))
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                    .foregroundStyle(.linearGradient(
                                        colors: [.neonPurple, .white],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            }
                            .width(min: 100)

                            TableColumn("Uptime") { process in
                                Text(process.uptimeFormatted)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .width(min: 100)

                            TableColumn("Actions") { process in
                                HStack(spacing: 10) {
                                    if process.status.lowercased() == "stopped" {
                                        Button(action: {
                                            Task {
                                                await viewModel.startProcess(process)
                                            }
                                        }) {
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.linearGradient(
                                                    colors: [.green, .green.opacity(0.7)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ))
                                                .shadow(color: .green.opacity(0.5), radius: 4, x: 0, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Start")
                                    } else {
                                        Button(action: {
                                            processToStop = process
                                            showingStopConfirmation = true
                                        }) {
                                            Image(systemName: "stop.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.linearGradient(
                                                    colors: [.orange, .orange.opacity(0.7)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ))
                                                .shadow(color: .orange.opacity(0.5), radius: 4, x: 0, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Stop")
                                    }

                                    Button(action: {
                                        Task {
                                            await viewModel.restartProcess(process)
                                        }
                                    }) {
                                        Image(systemName: "arrow.clockwise.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.linearGradient(
                                                colors: [.neonBlue, .neonBlue.opacity(0.7)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ))
                                            .shadow(color: .neonBlue.opacity(0.5), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Restart")

                                    Button(action: {
                                        processToDelete = process
                                        showingDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "trash.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.linearGradient(
                                                colors: [.red, .red.opacity(0.7)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ))
                                            .shadow(color: .red.opacity(0.5), radius: 4, x: 0, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete")
                                }
                            }
                            .width(min: 140)
                        }
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .glassEffect(cornerRadius: 16, intensity: .medium)
                        .padding(20)
                        .id(viewModel.filteredProcesses.map { "\($0.id)-\($0.status)-\($0.pid ?? 0)" }.joined())
                        .onChange(of: selectedProcessSet) { newValue in
                            if let selectedId = newValue.first,
                               let process = viewModel.filteredProcesses.first(where: { $0.id == selectedId }) {
                                viewModel.selectedProcess = process
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showingSideDrawer = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .alert("Stop Process", isPresented: $showingStopConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                if let process = processToStop {
                    Task {
                        await viewModel.stopProcess(process)
                    }
                }
            }
        } message: {
            if let process = processToStop {
                Text("Are you sure you want to stop '\(process.name)'?")
            }
        }
        .alert("Delete Process", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let process = processToDelete {
                    Task {
                        await viewModel.deleteProcess(process)
                    }
                }
            }
        } message: {
            if let process = processToDelete {
                Text("Are you sure you want to delete '\(process.name)'? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showingDiagnostics) {
            ZStack {
                // Deep dark background
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.08),
                        Color(red: 0.02, green: 0.02, blue: 0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Diagnostics")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.linearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                        Spacer()
                        Button(action: {
                            showingDiagnostics = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.linearGradient(
                                    colors: [.white.opacity(0.6), .white.opacity(0.4)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)

                    GlowingDivider()
                        .padding(.horizontal, 24)

                    // Content
                    ScrollView {
                        Text(diagnosticInfo)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    GlowingDivider()
                        .padding(.horizontal, 24)

                    // Footer actions
                    HStack {
                        Spacer()
                        Button("Copy to Clipboard") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(diagnosticInfo, forType: .string)
                        }
                        .neonButton(color: .neonBlue, intensity: 0.8)

                        Button("Save to File") {
                            let panel = NSSavePanel()
                            panel.nameFieldStringValue = "pm2_diagnostics.txt"
                            panel.begin { response in
                                if response == .OK, let url = panel.url {
                                    try? diagnosticInfo.write(to: url, atomically: true, encoding: .utf8)
                                }
                            }
                        }
                        .neonButton(color: .neonPurple, intensity: 0.8)
                    }
                    .padding(24)
                }
            }
            .frame(width: 700, height: 500)
        }
    }

    @ViewBuilder
    private var sideDrawer: some View {
        if showingSideDrawer, let selectedProcess = viewModel.selectedProcess {
            ZStack(alignment: .trailing) {
                // Backdrop with blur
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showingSideDrawer = false
                            selectedProcessSet.removeAll()
                        }
                    }
                    .transition(.opacity)

                VStack(spacing: 0) {
                    // Drawer Content with integrated close button
                    ProcessDetailView(
                        process: selectedProcess,
                        onClose: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingSideDrawer = false
                                selectedProcessSet.removeAll()
                            }
                        }
                    )
                }
                .frame(width: 650)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0.85),
                                    Color(red: 0.02, green: 0.02, blue: 0.02).opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                }
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2)
                        .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 0)
                }
                .shadow(color: .black.opacity(0.6), radius: 30, x: -10, y: 0)
                .shadow(color: .black.opacity(0.3), radius: 50, x: -20, y: 0)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
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

// MARK: - Liquid Glass Components (inline for immediate availability)

extension Color {
    static var neonBlue: Color {
        Color(red: 0.3, green: 0.6, blue: 1.0)
    }

    static var neonPurple: Color {
        Color(red: 0.6, green: 0.3, blue: 1.0)
    }
}

struct GlowingDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.2),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .shadow(color: .white.opacity(0.1), radius: 2, x: 0, y: 0)
    }
}

struct GlowingStatusIndicator: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.8), radius: 4, x: 0, y: 0)
            .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 0)
    }
}

struct NeonGlowButtonStyle: ButtonStyle {
    let color: Color
    let intensity: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(white: 0.1).opacity(0.3))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Color.white.opacity(configuration.isPressed ? 0.4 : 0.2),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.3 : 0.15),
                radius: configuration.isPressed ? 8 : 12,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct LiquidGlassEffect: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: GlassIntensity

    enum GlassIntensity {
        case subtle
        case medium
        case strong

        var blurRadius: CGFloat {
            switch self {
            case .subtle: return 20
            case .medium: return 30
            case .strong: return 40
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .subtle: return 0.2
            case .medium: return 0.3
            case .strong: return 0.4
            }
        }

        var backgroundOpacity: Double {
            switch self {
            case .subtle: return 0.6
            case .medium: return 0.5
            case .strong: return 0.4
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            LinearGradient(
                                colors: [
                                    Color(white: 0.15).opacity(intensity.backgroundOpacity),
                                    Color(white: 0.05).opacity(intensity.backgroundOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
            }
            .shadow(color: .black.opacity(intensity.shadowOpacity), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.15), radius: 40, x: 0, y: 20)
    }
}

struct LiquidGlassTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.1).opacity(0.4),
                                        Color(white: 0.05).opacity(0.4)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
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
    }
}

extension View {
    func glassEffect(cornerRadius: CGFloat = 12, intensity: LiquidGlassEffect.GlassIntensity = .medium) -> some View {
        self.modifier(LiquidGlassEffect(cornerRadius: cornerRadius, intensity: intensity))
    }

    func neonButton(color: Color = .blue, intensity: CGFloat = 1.0) -> some View {
        self.buttonStyle(NeonGlowButtonStyle(color: color, intensity: intensity))
    }

    func liquidGlassTextField() -> some View {
        self.modifier(LiquidGlassTextFieldStyle())
    }
}

#Preview {
    ProcessListView()
}
