import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @EnvironmentObject var configManager: ConfigManager
    @StateObject private var resolverManager = ResolverManager()
    @State private var statusMessage: String = ""
    @State private var showStatus: Bool = false
    @State private var isSuccess: Bool = true
    @State private var isProcessing: Bool = false
    @State private var showImportSheet: Bool = false
    @State private var importText: String = ""
    @State private var showExportSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Backup & Restore")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Backup Section
                    SectionCard(title: "Backup Configuration", icon: "arrow.down.doc", color: .blue) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Save your current dnsmasq configuration and resolver files to a backup folder.")
                                .font(.callout)
                                .foregroundColor(.secondary)

                            HStack {
                                Button(action: { Task { await performBackup() } }) {
                                    Label("Create Backup", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isProcessing)

                                if isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }

                            Text("Backs up: dnsmasq.conf + /etc/resolver/* files")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Restore Section
                    SectionCard(title: "Restore Configuration", icon: "arrow.up.doc", color: .orange) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Restore a previous backup of your dnsmasq configuration.")
                                .font(.callout)
                                .foregroundColor(.secondary)

                            Button(action: { Task { await performRestore() } }) {
                                Label("Restore from Backup", systemImage: "arrow.counterclockwise")
                            }
                            .disabled(isProcessing)

                            Text("Select a backup folder created by Handed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Import Section
                    SectionCard(title: "Import from Hosts Format", icon: "doc.text", color: .green) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Import DNS entries from /etc/hosts format or paste entries directly.")
                                .font(.callout)
                                .foregroundColor(.secondary)

                            HStack {
                                Button(action: { Task { await importFromHostsFile() } }) {
                                    Label("Import /etc/hosts", systemImage: "doc.badge.arrow.up")
                                }

                                Button(action: { showImportSheet = true }) {
                                    Label("Paste Entries", systemImage: "doc.on.clipboard")
                                }
                            }
                            .disabled(isProcessing)

                            Text("Format: IP_ADDRESS HOSTNAME (e.g., 127.0.0.1 myapp.local)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Export Section
                    SectionCard(title: "Export Configuration", icon: "square.and.arrow.up", color: .purple) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Export your DNS records to various formats for sharing or documentation.")
                                .font(.callout)
                                .foregroundColor(.secondary)

                            HStack {
                                Button(action: { Task { await exportAsHosts() } }) {
                                    Label("Export as Hosts", systemImage: "doc.text")
                                }

                                Button(action: { Task { await exportAsDnsmasqConf() } }) {
                                    Label("Export dnsmasq.conf", systemImage: "doc.badge.gearshape")
                                }
                            }
                            .disabled(isProcessing)
                        }
                    }

                    // Quick TLD Presets Section
                    SectionCard(title: "Quick TLD Presets", icon: "wand.and.stars", color: .pink) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("One-click setup for common local development TLDs. Creates both DNS records and resolver files.")
                                .font(.callout)
                                .foregroundColor(.secondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                PresetButton(tld: "local", description: "*.local") {
                                    await setupTLDPreset("local")
                                }
                                PresetButton(tld: "test", description: "*.test") {
                                    await setupTLDPreset("test")
                                }
                                PresetButton(tld: "dev", description: "*.dev") {
                                    await setupTLDPreset("dev")
                                }
                                PresetButton(tld: "localhost", description: "*.localhost") {
                                    await setupTLDPreset("localhost")
                                }
                                PresetButton(tld: "internal", description: "*.internal") {
                                    await setupTLDPreset("internal")
                                }
                                PresetButton(tld: "lan", description: "*.lan") {
                                    await setupTLDPreset("lan")
                                }
                            }

                            Text("Each preset creates a resolver file pointing to 127.0.0.1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }

            // Status bar
            if showStatus {
                HStack {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isSuccess ? .green : .red)
                    Text(statusMessage)
                        .font(.callout)
                    Spacer()
                    Button("Dismiss") {
                        withAnimation { showStatus = false }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportSheet(importText: $importText) { entries in
                Task { await importEntries(entries) }
            }
        }
        .task {
            await resolverManager.loadResolverFiles()
        }
    }

    // MARK: - Backup/Restore Functions

    private func performBackup() async {
        isProcessing = true

        let panel = NSSavePanel()
        panel.title = "Choose Backup Location"
        panel.nameFieldStringValue = "handed-backup-\(dateString())"
        panel.canCreateDirectories = true

        let response = await panel.beginSheetModal(for: NSApp.keyWindow!)

        if response == .OK, let url = panel.url {
            do {
                // Create backup directory
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

                // Backup dnsmasq.conf
                let configPath = configManager.configPath
                let configDestination = url.appendingPathComponent("dnsmasq.conf")
                if FileManager.default.fileExists(atPath: configPath) {
                    try await copyWithAdminPrivileges(from: configPath, to: configDestination.path)
                }

                // Backup resolver files
                let resolverDir = url.appendingPathComponent("resolver")
                try FileManager.default.createDirectory(at: resolverDir, withIntermediateDirectories: true)

                for file in resolverManager.resolverFiles {
                    let content = file.toFileContent()
                    let destination = resolverDir.appendingPathComponent(file.domain)
                    try content.write(to: destination, atomically: true, encoding: .utf8)
                }

                // Save metadata
                let metadata: [String: Any] = [
                    "version": AppInfo.version,
                    "date": ISO8601DateFormatter().string(from: Date()),
                    "dnsmasqConfigPath": configPath,
                    "resolverCount": resolverManager.resolverFiles.count
                ]
                let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
                try metadataData.write(to: url.appendingPathComponent("backup-info.json"))

                showStatusMessage("Backup created successfully at \(url.lastPathComponent)", success: true)
            } catch {
                showStatusMessage("Backup failed: \(error.localizedDescription)", success: false)
            }
        }

        isProcessing = false
    }

    private func performRestore() async {
        isProcessing = true

        let panel = NSOpenPanel()
        panel.title = "Select Backup Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true

        let response = await panel.beginSheetModal(for: NSApp.keyWindow!)

        if response == .OK, let url = panel.url {
            do {
                // Check for valid backup
                let metadataURL = url.appendingPathComponent("backup-info.json")
                guard FileManager.default.fileExists(atPath: metadataURL.path) else {
                    throw RestoreError.invalidBackup("Not a valid Handed backup folder")
                }

                // Restore dnsmasq.conf
                let configSource = url.appendingPathComponent("dnsmasq.conf")
                if FileManager.default.fileExists(atPath: configSource.path) {
                    try await copyWithAdminPrivileges(from: configSource.path, to: configManager.configPath)
                }

                // Restore resolver files
                let resolverDir = url.appendingPathComponent("resolver")
                if FileManager.default.fileExists(atPath: resolverDir.path) {
                    let files = try FileManager.default.contentsOfDirectory(atPath: resolverDir.path)
                    for filename in files where !filename.hasPrefix(".") {
                        let source = resolverDir.appendingPathComponent(filename)
                        let destination = "/etc/resolver/\(filename)"
                        try await copyWithAdminPrivileges(from: source.path, to: destination)
                    }
                }

                // Reload configurations
                await configManager.loadConfig()
                await resolverManager.loadResolverFiles()

                showStatusMessage("Configuration restored successfully", success: true)
            } catch {
                showStatusMessage("Restore failed: \(error.localizedDescription)", success: false)
            }
        }

        isProcessing = false
    }

    private func importFromHostsFile() async {
        isProcessing = true

        do {
            let content = try await readWithAdminPrivileges("/etc/hosts")
            let entries = parseHostsFormat(content)

            if entries.isEmpty {
                showStatusMessage("No valid entries found in /etc/hosts", success: false)
            } else {
                for entry in entries {
                    configManager.addDNSRecord(entry)
                }
                showStatusMessage("Imported \(entries.count) entries from /etc/hosts", success: true)
            }
        } catch {
            showStatusMessage("Failed to read /etc/hosts: \(error.localizedDescription)", success: false)
        }

        isProcessing = false
    }

    private func importEntries(_ text: String) async {
        isProcessing = true

        let entries = parseHostsFormat(text)

        if entries.isEmpty {
            showStatusMessage("No valid entries found", success: false)
        } else {
            for entry in entries {
                configManager.addDNSRecord(entry)
            }
            showStatusMessage("Imported \(entries.count) entries", success: true)
        }

        isProcessing = false
    }

    private func exportAsHosts() async {
        isProcessing = true

        let panel = NSSavePanel()
        panel.title = "Export as Hosts File"
        panel.nameFieldStringValue = "hosts-export.txt"

        let response = await panel.beginSheetModal(for: NSApp.keyWindow!)

        if response == .OK, let url = panel.url {
            var content = "# Exported from Handed - \(Date())\n"
            content += "# DNS Records from dnsmasq configuration\n\n"

            for record in configManager.config.dnsRecords where record.recordType == .address {
                content += "\(record.value)\t\(record.domain)"
                if let comment = record.comment {
                    content += "\t# \(comment)"
                }
                content += "\n"
            }

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                showStatusMessage("Exported to \(url.lastPathComponent)", success: true)
            } catch {
                showStatusMessage("Export failed: \(error.localizedDescription)", success: false)
            }
        }

        isProcessing = false
    }

    private func exportAsDnsmasqConf() async {
        isProcessing = true

        let panel = NSSavePanel()
        panel.title = "Export dnsmasq.conf"
        panel.nameFieldStringValue = "dnsmasq-export.conf"

        let response = await panel.beginSheetModal(for: NSApp.keyWindow!)

        if response == .OK, let url = panel.url {
            do {
                let content = configManager.config.toConfigString()
                try content.write(to: url, atomically: true, encoding: .utf8)
                showStatusMessage("Exported to \(url.lastPathComponent)", success: true)
            } catch {
                showStatusMessage("Export failed: \(error.localizedDescription)", success: false)
            }
        }

        isProcessing = false
    }

    private func setupTLDPreset(_ tld: String) async {
        isProcessing = true

        do {
            // Create resolver file
            let resolverFile = ResolverFile(
                domain: tld,
                nameservers: ["127.0.0.1"],
                comment: "Created by Handed for *.\(tld) domains"
            )

            let success = await resolverManager.saveResolverFile(resolverFile)

            if success {
                showStatusMessage("Created resolver for *.\(tld) → 127.0.0.1", success: true)
            } else {
                showStatusMessage("Failed to create resolver for .\(tld)", success: false)
            }
        }

        isProcessing = false
    }

    // MARK: - Helper Functions

    private func parseHostsFormat(_ content: String) -> [DNSRecord] {
        var records: [DNSRecord] = []

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse: IP HOSTNAME [HOSTNAME...]
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { continue }

            let ip = parts[0]
            // Validate IP format (basic check)
            guard ip.contains(".") || ip.contains(":") else { continue }
            // Skip localhost entries
            guard ip != "127.0.0.1" || !parts[1].hasPrefix("localhost") else { continue }

            for hostname in parts.dropFirst() {
                // Skip comments in the middle of the line
                if hostname.hasPrefix("#") { break }

                let record = DNSRecord(
                    recordType: .address,
                    domain: hostname,
                    value: ip,
                    comment: "Imported from hosts"
                )
                records.append(record)
            }
        }

        return records
    }

    private func copyWithAdminPrivileges(from source: String, to destination: String) async throws {
        let script = """
            do shell script "cp '\(source)' '\(destination)'" with administrator privileges
            """
        _ = try await runAppleScript(script)
    }

    private func readWithAdminPrivileges(_ path: String) async throws -> String {
        // Try direct read first
        if FileManager.default.isReadableFile(atPath: path) {
            return try String(contentsOfFile: path, encoding: .utf8)
        }

        let script = """
            do shell script "cat '\(path)'" with administrator privileges
            """
        return try await runAppleScript(script)
    }

    private func runAppleScript(_ script: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)

                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: RestoreError.scriptError(message))
                } else {
                    continuation.resume(returning: result?.stringValue ?? "")
                }
            }
        }
    }

    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }

    private func showStatusMessage(_ message: String, success: Bool) {
        statusMessage = message
        isSuccess = success
        withAnimation { showStatus = true }

        // Auto-hide after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation { showStatus = false }
        }
    }

    enum RestoreError: LocalizedError {
        case invalidBackup(String)
        case scriptError(String)

        var errorDescription: String? {
            switch self {
            case .invalidBackup(let message): return message
            case .scriptError(let message): return "Script error: \(message)"
            }
        }
    }
}

// MARK: - Helper Views

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct PresetButton: View {
    let tld: String
    let description: String
    let action: () async -> Void

    @State private var isRunning = false

    var body: some View {
        Button(action: {
            Task {
                isRunning = true
                await action()
                isRunning = false
            }
        }) {
            VStack(spacing: 4) {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text(".\(tld)")
                        .font(.headline)
                }
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 80)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .disabled(isRunning)
    }
}

struct ImportSheet: View {
    @Binding var importText: String
    let onImport: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import DNS Entries")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Paste entries in hosts file format (IP ADDRESS followed by HOSTNAME):")
                    .font(.callout)
                    .foregroundColor(.secondary)

                TextEditor(text: $importText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color(NSColor.separatorColor), width: 1)

                Text("Example:\n127.0.0.1 myapp.local\n192.168.1.100 database.internal api.internal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Import") {
                    onImport(importText)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

#Preview {
    BackupRestoreView()
        .environmentObject(ConfigManager())
}
