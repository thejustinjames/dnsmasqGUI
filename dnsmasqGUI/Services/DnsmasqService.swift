import Foundation
import Combine

/// Manages the dnsmasq service via Homebrew services
@MainActor
class DnsmasqService: ObservableObject {
    @Published var status: ServiceStatus = .unknown
    @Published var isProcessing: Bool = false
    @Published var lastOutput: String = ""

    private var statusTimer: Timer?

    init() {
        startStatusMonitoring()
    }

    deinit {
        statusTimer?.invalidate()
    }

    /// Start the dnsmasq service
    func start() async {
        isProcessing = true
        lastOutput = ""

        do {
            let output = try await runBrewCommand("start")
            lastOutput = output
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
            let output = try await runBrewCommand("stop")
            lastOutput = output
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
            let output = try await runBrewCommand("restart")
            lastOutput = output
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
        do {
            let output = try await runShellCommand("/opt/homebrew/bin/brew services list")
            parseStatus(from: output)
        } catch {
            status = ServiceStatus(state: .unknown, errorMessage: error.localizedDescription)
        }
    }

    /// Validate the configuration file
    func validateConfig() async -> (valid: Bool, message: String) {
        do {
            let output = try await runShellCommand("/opt/homebrew/sbin/dnsmasq --test")
            if output.lowercased().contains("syntax check ok") {
                return (true, "Configuration is valid")
            } else {
                return (false, output)
            }
        } catch {
            return (false, "Validation error: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func startStatusMonitoring() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkStatus()
            }
        }
    }

    private func parseStatus(from output: String) {
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

        status = ServiceStatus(state: .unknown, errorMessage: "dnsmasq not found in services list")
    }

    private func runBrewCommand(_ action: String) async throws -> String {
        let command = "/opt/homebrew/bin/brew services \(action) dnsmasq"

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

    enum ServiceError: LocalizedError {
        case appleScriptError(String)
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .appleScriptError(let message):
                return "AppleScript error: \(message)"
            case .commandFailed(let message):
                return "Command failed: \(message)"
            }
        }
    }
}
