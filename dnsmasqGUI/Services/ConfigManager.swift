import Foundation
import Combine

/// Manages reading and writing the dnsmasq configuration file
@MainActor
class ConfigManager: ObservableObject {
    @Published var config: DnsmasqConfig = DnsmasqConfig()
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var hasUnsavedChanges: Bool = false

    let configPath: String

    init(configPath: String = "/opt/homebrew/etc/dnsmasq.conf") {
        self.configPath = configPath
    }

    /// Load configuration from file
    func loadConfig() async {
        isLoading = true
        error = nil

        do {
            let content = try await readConfigFile()
            config = DnsmasqConfig.parse(from: content)
            hasUnsavedChanges = false
        } catch {
            self.error = "Failed to load config: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Save configuration to file
    func saveConfig() async -> Bool {
        isLoading = true
        error = nil

        do {
            let content = config.toConfigString()
            try await writeConfigFile(content: content)
            hasUnsavedChanges = false
            isLoading = false
            return true
        } catch {
            self.error = "Failed to save config: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    /// Add a DNS record
    func addDNSRecord(_ record: DNSRecord) {
        config.dnsRecords.append(record)
        hasUnsavedChanges = true
    }

    /// Update a DNS record
    func updateDNSRecord(_ record: DNSRecord) {
        if let index = config.dnsRecords.firstIndex(where: { $0.id == record.id }) {
            config.dnsRecords[index] = record
            hasUnsavedChanges = true
        }
    }

    /// Delete a DNS record
    func deleteDNSRecord(_ record: DNSRecord) {
        config.dnsRecords.removeAll { $0.id == record.id }
        hasUnsavedChanges = true
    }

    /// Add a DHCP lease entry
    func addDHCPLease(_ lease: DHCPLease) {
        config.dhcpLeases.append(lease)
        hasUnsavedChanges = true
    }

    /// Update a DHCP lease entry
    func updateDHCPLease(_ lease: DHCPLease) {
        if let index = config.dhcpLeases.firstIndex(where: { $0.id == lease.id }) {
            config.dhcpLeases[index] = lease
            hasUnsavedChanges = true
        }
    }

    /// Delete a DHCP lease entry
    func deleteDHCPLease(_ lease: DHCPLease) {
        config.dhcpLeases.removeAll { $0.id == lease.id }
        hasUnsavedChanges = true
    }

    // MARK: - Private Methods

    private func readConfigFile() async throws -> String {
        // Try to read directly first
        let fileURL = URL(fileURLWithPath: configPath)

        if FileManager.default.isReadableFile(atPath: configPath) {
            return try String(contentsOf: fileURL, encoding: .utf8)
        }

        // If not readable, use sudo via AppleScript
        let script = """
            do shell script "cat '\(configPath)'" with administrator privileges
            """

        return try await runAppleScript(script)
    }

    private func writeConfigFile(content: String) async throws {
        // Create a temporary file with the content
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("dnsmasq_temp_\(UUID().uuidString).conf")

        try content.write(to: tempURL, atomically: true, encoding: .utf8)

        // Copy the temp file to the config location with admin privileges
        let script = """
            do shell script "cp '\(tempURL.path)' '\(configPath)'" with administrator privileges
            """

        _ = try await runAppleScript(script)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
    }

    private func runAppleScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: ConfigError.appleScriptError(message))
                } else {
                    continuation.resume(returning: result?.stringValue ?? "")
                }
            }
        }
    }

    enum ConfigError: LocalizedError {
        case appleScriptError(String)
        case fileNotFound
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .appleScriptError(let message):
                return "AppleScript error: \(message)"
            case .fileNotFound:
                return "Configuration file not found"
            case .parseError(let message):
                return "Parse error: \(message)"
            }
        }
    }
}
