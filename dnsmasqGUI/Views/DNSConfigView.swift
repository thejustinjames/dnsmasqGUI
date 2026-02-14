import SwiftUI

struct DNSConfigView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedRecord: DNSRecord?
    @State private var isAddingRecord = false
    @State private var isEditingRecord = false
    @State private var recordToEdit: DNSRecord?
    @State private var recordToDelete: DNSRecord?
    @State private var showDeleteConfirmation = false
    @State private var testResult: DNSTestResult?
    @State private var showTestResult = false
    @State private var isTesting = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("DNS Records")
                    .font(.headline)

                Spacer()

                if configManager.hasUnsavedChanges {
                    Text("Unsaved Changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Button(action: { isAddingRecord = true }) {
                    Label("Add Record", systemImage: "plus")
                }

                Button(action: {
                    if let record = selectedRecord {
                        recordToEdit = record
                        isEditingRecord = true
                    }
                }) {
                    Label("Edit", systemImage: "pencil")
                }
                .disabled(selectedRecord == nil)

                Button(action: {
                    if let record = selectedRecord {
                        testDNSRecord(record)
                    }
                }) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Test", systemImage: "play.circle")
                    }
                }
                .disabled(selectedRecord == nil || isTesting)

                Button(action: {
                    if let record = selectedRecord {
                        recordToDelete = record
                        showDeleteConfirmation = true
                    }
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedRecord == nil)

                Divider()
                    .frame(height: 20)

                Button(action: {
                    Task {
                        await configManager.saveConfig()
                    }
                }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(!configManager.hasUnsavedChanges)

                Button(action: {
                    Task {
                        await configManager.loadConfig()
                    }
                }) {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            if configManager.isLoading {
                Spacer()
                ProgressView("Loading configuration...")
                Spacer()
            } else if let error = configManager.error {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task {
                            await configManager.loadConfig()
                        }
                    }
                }
                Spacer()
            } else if configManager.config.dnsRecords.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "network.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No DNS records configured")
                        .foregroundColor(.secondary)
                    Text("Add DNS overrides, upstream servers, or local-only domains")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Add Your First Record") {
                        isAddingRecord = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            } else {
                List(selection: $selectedRecord) {
                    ForEach(configManager.config.dnsRecords) { record in
                        DNSRecordRow(record: record, onEdit: {
                            recordToEdit = record
                            isEditingRecord = true
                        }, onTest: {
                            testDNSRecord(record)
                        })
                        .tag(record)
                        .contextMenu {
                            Button("Edit") {
                                recordToEdit = record
                                isEditingRecord = true
                            }
                            Button("Test Resolution") {
                                testDNSRecord(record)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                recordToDelete = record
                                showDeleteConfirmation = true
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $isAddingRecord) {
            DNSRecordEditor(mode: .add) { record in
                configManager.addDNSRecord(record)
            }
        }
        .sheet(isPresented: $isEditingRecord) {
            if let record = recordToEdit {
                DNSRecordEditor(mode: .edit(record)) { updatedRecord in
                    configManager.updateDNSRecord(updatedRecord)
                }
            }
        }
        .sheet(isPresented: $showTestResult) {
            if let result = testResult {
                DNSTestResultView(result: result)
            }
        }
        .alert("Delete Record", isPresented: $showDeleteConfirmation, presenting: recordToDelete) { record in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                configManager.deleteDNSRecord(record)
                selectedRecord = nil
            }
        } message: { record in
            Text("Are you sure you want to delete the record for '\(record.domain)'?")
        }
    }

    private func testDNSRecord(_ record: DNSRecord) {
        isTesting = true
        Task {
            let result = await performDNSTest(record)
            await MainActor.run {
                testResult = result
                showTestResult = true
                isTesting = false
            }
        }
    }

    private func performDNSTest(_ record: DNSRecord) async -> DNSTestResult {
        let domain = record.domain
        let expectedIP = record.value

        // Test using dig against localhost (dnsmasq)
        do {
            let output = try await runCommand("dig @127.0.0.1 \(domain) +short +time=2 +tries=1")
            let resolvedIP = output.trimmingCharacters(in: .whitespacesAndNewlines)

            if resolvedIP.isEmpty {
                return DNSTestResult(
                    record: record,
                    success: false,
                    resolvedValue: nil,
                    message: "No response from DNS server. Is dnsmasq running?",
                    responseTime: nil
                )
            }

            let matches = resolvedIP == expectedIP || record.recordType == .local
            return DNSTestResult(
                record: record,
                success: matches,
                resolvedValue: resolvedIP,
                message: matches ? "DNS resolution successful" : "Resolved IP doesn't match expected value",
                responseTime: nil
            )
        } catch {
            return DNSTestResult(
                record: record,
                success: false,
                resolvedValue: nil,
                message: "Test failed: \(error.localizedDescription)",
                responseTime: nil
            )
        }
    }

    private func runCommand(_ command: String) async throws -> String {
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
}

struct DNSTestResult {
    let record: DNSRecord
    let success: Bool
    let resolvedValue: String?
    let message: String
    let responseTime: TimeInterval?
}

struct DNSTestResultView: View {
    let result: DNSTestResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DNS Test Result")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding()

            Divider()

            VStack(spacing: 20) {
                // Status icon
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(result.success ? .green : .red)

                Text(result.success ? "Test Passed" : "Test Failed")
                    .font(.title2)
                    .fontWeight(.semibold)

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Domain:")
                            .foregroundColor(.secondary)
                        Text(result.record.domain)
                            .fontWeight(.medium)
                    }

                    if !result.record.value.isEmpty {
                        HStack {
                            Text("Expected:")
                                .foregroundColor(.secondary)
                            Text(result.record.value)
                                .fontWeight(.medium)
                        }
                    }

                    if let resolved = result.resolvedValue {
                        HStack {
                            Text("Resolved:")
                                .foregroundColor(.secondary)
                            Text(resolved)
                                .fontWeight(.medium)
                                .foregroundColor(result.success ? .green : .orange)
                        }
                    }

                    Divider()

                    Text(result.message)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            }
            .padding()

            Spacer()

            Divider()

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 400)
    }
}

struct DNSRecordRow: View {
    let record: DNSRecord
    let onEdit: () -> Void
    let onTest: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.recordType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor.opacity(0.2))
                        .foregroundColor(typeColor)
                        .cornerRadius(4)

                    Text(record.domain)
                        .font(.body)
                        .fontWeight(.medium)
                }

                if !record.value.isEmpty {
                    HStack {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(record.value)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let comment = record.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onTest) {
                    Image(systemName: "play.circle")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Test DNS resolution")

                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Edit record")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onEdit()
        }
    }

    private var typeColor: Color {
        switch record.recordType {
        case .address: return .blue
        case .server: return .green
        case .local: return .orange
        }
    }
}

struct DNSRecordEditor: View {
    enum Mode {
        case add
        case edit(DNSRecord)
    }

    let mode: Mode
    let onSave: (DNSRecord) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var recordType: DNSRecord.RecordType = .address
    @State private var domain: String = ""
    @State private var value: String = ""
    @State private var comment: String = ""

    private var existingId: UUID?

    init(mode: Mode, onSave: @escaping (DNSRecord) -> Void) {
        self.mode = mode
        self.onSave = onSave

        if case .edit(let record) = mode {
            _recordType = State(initialValue: record.recordType)
            _domain = State(initialValue: record.domain)
            _value = State(initialValue: record.value)
            _comment = State(initialValue: record.comment ?? "")
        }
    }

    private var isValid: Bool {
        !domain.isEmpty && (recordType == .local || !value.isEmpty)
    }

    private var placeholderDomain: String {
        switch recordType {
        case .address: return "example.local"
        case .server: return "corp.example.com (or empty for all)"
        case .local: return "internal.lan"
        }
    }

    private var placeholderValue: String {
        switch recordType {
        case .address: return "192.168.1.100"
        case .server: return "10.0.0.1 or 8.8.8.8"
        case .local: return ""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mode.isEditing ? "Edit DNS Record" : "Add DNS Record")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Type selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Record Type")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Type", selection: $recordType) {
                            ForEach(DNSRecord.RecordType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        // Type description with example
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recordType.description)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(exampleText)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 2)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }

                    Divider()

                    // Domain field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Domain")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField(placeholderDomain, text: $domain)
                            .textFieldStyle(.roundedBorder)

                        Text(domainHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Value field (not for local type)
                    if recordType != .local {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recordType == .address ? "IP Address" : "DNS Server")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            TextField(placeholderValue, text: $value)
                                .textFieldStyle(.roundedBorder)

                            Text(valueHint)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Comment field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comment (optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Description or notes", text: $comment)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Config Preview")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(configPreview)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.textBackgroundColor))
                            )
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button(mode.isEditing ? "Save" : "Add Record") {
                    let id: UUID
                    if case .edit(let record) = mode {
                        id = record.id
                    } else {
                        id = UUID()
                    }

                    let record = DNSRecord(
                        id: id,
                        recordType: recordType,
                        domain: domain,
                        value: value,
                        comment: comment.isEmpty ? nil : comment
                    )
                    onSave(record)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
    }

    private var exampleText: String {
        switch recordType {
        case .address:
            return "Example: address=/myapp.local/127.0.0.1"
        case .server:
            return "Example: server=/corp.com/10.0.0.1"
        case .local:
            return "Example: local=/internal.lan/"
        }
    }

    private var domainHint: String {
        switch recordType {
        case .address:
            return "The domain name to override (e.g., myapp.local)"
        case .server:
            return "Domain to route to specific DNS, or leave empty for all queries"
        case .local:
            return "Domain that should only be answered locally"
        }
    }

    private var valueHint: String {
        switch recordType {
        case .address:
            return "The IP address this domain should resolve to"
        case .server:
            return "The DNS server IP to use for this domain"
        case .local:
            return ""
        }
    }

    private var configPreview: String {
        if domain.isEmpty {
            return "# Enter a domain to see preview"
        }

        let record = DNSRecord(
            recordType: recordType,
            domain: domain,
            value: value,
            comment: comment.isEmpty ? nil : comment
        )
        return record.toConfigLine()
    }
}

extension DNSRecordEditor.Mode {
    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }
}

#Preview {
    DNSConfigView()
        .environmentObject(ConfigManager())
}
