//
//  PM2Process.swift
//  PM2GUI
//
//  Created by Dinindu Wanniarachchi on 2025-12-18.
//

import Foundation

struct PM2Process: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let pm2_env: PM2Environment
    let pid: Int?  // Optional - stopped processes don't have a PID
    let monit: ProcessMonit

    // Hashable conformance - use id for hashing
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PM2Process, rhs: PM2Process) -> Bool {
        lhs.id == rhs.id
    }

    var status: String {
        pm2_env.status
    }

    var cpuUsage: Double {
        monit.cpu
    }

    var memoryUsage: Double {
        Double(monit.memory) / 1_048_576 // Convert bytes to MB
    }

    var uptime: TimeInterval {
        guard let pmUptime = pm2_env.pm_uptime else { return 0 }
        return Date().timeIntervalSince1970 - Double(pmUptime) / 1000.0
    }

    var restartCount: Int {
        pm2_env.restart_time ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case name, pid, monit
        case id = "pm_id"
        case pm2_env = "pm2_env"
    }
}

struct PM2Environment: Codable, Hashable {
    let status: String
    let pm_uptime: Int?
    let restart_time: Int?
    let exec_mode: String?
    let pm_exec_path: String?
    let created_at: Int?
    let version: String?
    let node_version: String?

    // Custom decoder to handle PM2's variable JSON structure
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        status = try container.decode(String.self, forKey: .status)

        // All other fields are optional and may not be present
        pm_uptime = try? container.decode(Int.self, forKey: .pm_uptime)
        restart_time = try? container.decode(Int.self, forKey: .restart_time)
        exec_mode = try? container.decode(String.self, forKey: .exec_mode)
        pm_exec_path = try? container.decode(String.self, forKey: .pm_exec_path)
        created_at = try? container.decode(Int.self, forKey: .created_at)
        version = try? container.decode(String.self, forKey: .version)
        node_version = try? container.decode(String.self, forKey: .node_version)
    }

    // Manual initializer for testing/previews
    init(status: String, pm_uptime: Int? = nil, restart_time: Int? = nil, exec_mode: String? = nil,
         pm_exec_path: String? = nil, created_at: Int? = nil, version: String? = nil, node_version: String? = nil) {
        self.status = status
        self.pm_uptime = pm_uptime
        self.restart_time = restart_time
        self.exec_mode = exec_mode
        self.pm_exec_path = pm_exec_path
        self.created_at = created_at
        self.version = version
        self.node_version = node_version
    }

    enum CodingKeys: String, CodingKey {
        case status
        case pm_uptime
        case restart_time
        case exec_mode
        case pm_exec_path
        case created_at
        case version
        case node_version
    }
}

struct ProcessMonit: Codable, Hashable {
    let memory: Int
    let cpu: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memory = try container.decode(Int.self, forKey: .memory)

        // CPU can be either Int or Double in PM2 output
        if let cpuDouble = try? container.decode(Double.self, forKey: .cpu) {
            cpu = cpuDouble
        } else if let cpuInt = try? container.decode(Int.self, forKey: .cpu) {
            cpu = Double(cpuInt)
        } else {
            cpu = 0.0
        }
    }

    init(memory: Int, cpu: Double) {
        self.memory = memory
        self.cpu = cpu
    }
}

struct PM2ProcessDetail: Codable {
    let process: PM2Process
    let metadata: PM2Metadata?

    init(process: PM2Process, metadata: PM2Metadata? = nil) {
        self.process = process
        self.metadata = metadata
    }
}

struct PM2Metadata: Codable {
    let script_path: String?
    let exec_mode: String?
    let environment_variables: [String: String]?
    let start_time: Int?
    let uptime: Int?
    let restart_count: Int?

    enum CodingKeys: String, CodingKey {
        case script_path
        case exec_mode
        case environment_variables
        case start_time
        case uptime
        case restart_count
    }
}

extension PM2Process {
    var uptimeFormatted: String {
        let interval = uptime
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    var statusColor: String {
        switch status.lowercased() {
        case "online":
            return "green"
        case "stopped":
            return "gray"
        case "errored", "error":
            return "red"
        case "stopping":
            return "orange"
        case "launching":
            return "blue"
        default:
            return "gray"
        }
    }
}
