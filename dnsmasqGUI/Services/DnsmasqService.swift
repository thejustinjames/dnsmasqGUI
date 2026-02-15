import Foundation
import Combine

/// Execution mode for dnsmasq
enum DnsmasqMode: String, CaseIterable, Identifiable {
    case homebrew = "Homebrew Services"
    case local = "Local Process"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .homebrew:
            return "Manage via 'brew services' (recommended for persistent service)"
        case .local:
            return "Run dnsmasq directly as a local process"
        }
    }
}

/// Manages the dnsmasq service via Homebrew services or local process
@MainActor
class DnsmasqService: ObservableObject {
    @Published var status: ServiceStatus = .unknown
    @Published var isProcessing: Bool = false
    @Published var lastOutput: String = ""
    @Published var mode: DnsmasqMode = .homebrew
    @Published var dnsmasqPath: String = "/opt/homebrew/sbin/dnsmasq"
    @Published var configPath: String = "/opt/homebrew/etc/dnsmasq.conf"

    private var statusTimer: Timer?
    private var localProcess: Process?
    private var localProcessPID: Int32?

    init() {
        detectDnsmasqPath()
        startStatusMonitoring()
    }

    deinit {
        statusTimer?.invalidate()
    }

    /// Detect dnsmasq installation path
    private func detectDnsmasqPath() {
        // Check common paths
        let paths = [
            "/opt/homebrew/sbin/dnsmasq",  // Apple Silicon Homebrew
            "/usr/local/sbin/dnsmasq",      // Intel Homebrew
            "/usr/sbin/dnsmasq",            // System install
            "/usr/local/bin/dnsmasq"        // Alternative location
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                dnsmasqPath = path
                break
            }
        }

        // Detect config path based on dnsmasq location
        if dnsmasqPath.contains("/opt/homebrew") {
            configPath = "/opt/homebrew/etc/dnsmasq.conf"
        } else if dnsmasqPath.contains("/usr/local") {
            configPath = "/usr/local/etc/dnsmasq.conf"
        } else {
            configPath = "/etc/dnsmasq.conf"
        }
    }

    /// Start the dnsmasq service
    func start() async {
        isProcessing = true
        lastOutput = ""

        do {
            switch mode {
            case .homebrew:
                let output = try await runBrewCommand("start")
                lastOutput = output
            case .local:
                try await startLocalProcess()
            }
            // Wait a moment for the service to start
            try? await Task.sleep(nanoseconds: 500_000_000)
            await checkStatus()
        } catch {
            lastOutput = "Error: \(error.localizedDescription)"
            status = ServiceStatus(state: .error, errorMessage: error.localizedDescription)
        }

        isProcessing = false
    }

    /// Stop the dnsmasq service
    func stop() async {
        isProcessing = true
        lastOutput = ""

        do {
            switch mode {
            case .homebrew:
                let output = try await runBrewCommand("stop")
                lastOutput = output
            case .local:
                try await stopLocalProcess()
            }
            // Wait a moment for the service to stop
            try? await Task.sleep(nanoseconds: 500_000_000)
            await checkStatus()
        } catch {
            lastOutput = "Error: \(error.localizedDescription)"
            status = ServiceStatus(state: .error, errorMessage: error.localizedDescription)
        }

        isProcessing = false
    }

    /// Restart the dnsmasq service
    func restart() async {
        isProcessing = true
        lastOutput = ""

        do {
            switch mode {
            case .homebrew:
                let output = try await runBrewCommand("restart")
                lastOutput = output
            case .local:
                try await stopLocalProcess()
                try? await Task.sleep(nanoseconds: 500_000_000)
                try await startLocalProcess()
            }
            // Wait a moment for the service to restart
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await checkStatus()
        } catch {
            lastOutput = "Error: \(error.localizedDescription)"
            status = ServiceStatus(state: .error, errorMessage: error.localizedDescription)
        }

        isProcessing = false
    }

    /// Check the current status of the service
    func checkStatus() async {
        switch mode {
        case .homebrew:
            await checkHomebrewStatus()
        case .local:
            await checkLocalStatus()
        }
    }

    /// Validate the configuration file
    func validateConfig() async -> (valid: Bool, message: String) {
        do {
            let output = try await runShellCommand("\(dnsmasqPath) --test -C \(configPath)")
            if output.lowercased().contains("syntax check ok") {
                return (true, "Configuration is valid")
            } else {
                return (false, output)
            }
        } catch {
            return (false, "Validation error: \(error.localizedDescription)")
        }
    }

    // MARK: - Local Process Management

    private func startLocalProcess() async throws {
        // First, check if dnsmasq is already running
        let existingPID = try? await findDnsmasqPID()
        if existingPID != nil {
            lastOutput = "dnsmasq is already running"
            return
        }

        // Start dnsmasq with admin privileges (needed for port 53)
        let script = """
            do shell script "\(dnsmasqPath) -C \(configPath)" with administrator privileges
            """

        lastOutput = "Starting dnsmasq locally..."

        // Run in background using AppleScript for privilege escalation
        _ = try await runAppleScriptBackground(script)
        lastOutput = "dnsmasq started locally"
    }

    private func stopLocalProcess() async throws {
        // Find and kill the dnsmasq process
        if let pid = try? await findDnsmasqPID() {
            let script = """
                do shell script "kill \(pid)" with administrator privileges
                """
            _ = try await runAppleScript(script)
            lastOutput = "dnsmasq stopped (PID: \(pid))"
            localProcessPID = nil
        } else {
            // Try to kill by name
            let script = """
                do shell script "pkill -f dnsmasq || true" with administrator privileges
                """
            _ = try await runAppleScript(script)
            lastOutput = "dnsmasq stop command sent"
        }
    }

    private func findDnsmasqPID() async throws -> Int? {
        let output = try await runShellCommand("pgrep -f 'dnsmasq.*-C' || pgrep dnsmasq || true")
        let pidString = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let pid = Int(pidString.components(separatedBy: .newlines).first ?? "") {
            return pid
        }
        return nil
    }

    private func checkLocalStatus() async {
        do {
            if let pid = try await findDnsmasqPID() {
                status = ServiceStatus(state: .running, pid: pid)
            } else {
                status = ServiceStatus(state: .stopped)
            }
        } catch {
            status = ServiceStatus(state: .unknown, errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Homebrew Service Management

    private func checkHomebrewStatus() async {
        do {
            let output = try await runShellCommand("/opt/homebrew/bin/brew services list 2>/dev/null || /usr/local/bin/brew services list 2>/dev/null || echo 'brew not found'")
            parseHomebrewStatus(from: output)
        } catch {
            status = ServiceStatus(state: .unknown, errorMessage: error.localizedDescription)
        }
    }

    private func parseHomebrewStatus(from output: String) {
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if line.contains("dnsmasq") {
                // Parse brew services list output format: Name Status User File
                let components = line.split(separator: " ", omittingEmptySubsequences: true)

                if components.count >= 2 {
                    let statusStr = String(components[1]).lowercased()

                    if statusStr == "started" || statusStr == "running" {
                        // Try to get PID
                        var pid: Int? = nil
                        if let pidIndex = components.firstIndex(where: { Int($0) != nil && Int($0)! > 100 }) {
                            pid = Int(components[pidIndex])
                        }
                        status = ServiceStatus(state: .running, pid: pid)
                    } else if statusStr == "stopped" || statusStr == "none" {
                        status = ServiceStatus(state: .stopped)
                    } else if statusStr == "error" {
                        status = ServiceStatus(state: .error, errorMessage: "Service in error state")
                    } else {
                        status = ServiceStatus(state: .unknown)
                    }
                    return
                }
            }
        }

        // If not found in brew services, check if running locally
        Task {
            await checkLocalStatus()
        }
    }

    // MARK: - Status Monitoring

    private func startStatusMonitoring() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkStatus()
            }
        }
    }

    // MARK: - Command Execution

    private func runBrewCommand(_ action: String) async throws -> String {
        // Find brew path
        let brewPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew")
            ? "/opt/homebrew/bin/brew"
            : "/usr/local/bin/brew"

        let command = "\(brewPath) services \(action) dnsmasq"

        // brew services typically needs sudo for system services
        let script = """
            do shell script "\(command)" with administrator privileges
            """

        return try await runAppleScript(script)
    }

    private func runShellCommand(_ command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runAppleScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: ServiceError.appleScriptError(message))
                } else {
                    continuation.resume(returning: result?.stringValue ?? "")
                }
            }
        }
    }

    private func runAppleScriptBackground(_ script: String) async throws -> String {
        // For background execution, we use a different approach
        let backgroundScript = """
            do shell script "\(dnsmasqPath) -C \(configPath) &> /dev/null & echo $!" with administrator privileges
            """

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: backgroundScript)
                let result = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: ServiceError.appleScriptError(message))
                } else {
                    let pid = result?.stringValue ?? ""
                    continuation.resume(returning: pid)
                }
            }
        }
    }

    enum ServiceError: LocalizedError {
        case appleScriptError(String)
        case commandFailed(String)
        case notFound

        var errorDescription: String? {
            switch self {
            case .appleScriptError(let message):
                return "AppleScript error: \(message)"
            case .commandFailed(let message):
                return "Command failed: \(message)"
            case .notFound:
                return "dnsmasq not found"
            }
        }
    }
}
