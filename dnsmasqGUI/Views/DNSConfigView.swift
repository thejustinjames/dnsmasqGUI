import SwiftUI

struct DNSConfigView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedRecord: DNSRecord?
    @State private var isAddingRecord = false
    @State private var isEditingRecord = false
    @State private var recordToDelete: DNSRecord?
    @State private var showDeleteConfirmation = false

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
                    Button("Add Record") {
                        isAddingRecord = true
                    }
                }
                Spacer()
            } else {
                List(selection: $selectedRecord) {
                    ForEach(configManager.config.dnsRecords) { record in
                        DNSRecordRow(record: record)
                            .tag(record)
                            .contextMenu {
                                Button("Edit") {
                                    selectedRecord = record
                                    isEditingRecord = true
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
            if let record = selectedRecord {
                DNSRecordEditor(mode: .edit(record)) { updatedRecord in
                    configManager.updateDNSRecord(updatedRecord)
                }
            }
        }
        .alert("Delete Record", isPresented: $showDeleteConfirmation, presenting: recordToDelete) { record in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                configManager.deleteDNSRecord(record)
            }
        } message: { record in
            Text("Are you sure you want to delete the record for '\(record.domain)'?")
        }
    }
}

struct DNSRecordRow: View {
    let record: DNSRecord

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
                    Text(record.value)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let comment = record.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
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

            // Form
            Form {
                Picker("Type", selection: $recordType) {
                    ForEach(DNSRecord.RecordType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Text(recordType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Domain", text: $domain)
                    .textFieldStyle(.roundedBorder)

                if recordType != .local {
                    TextField(recordType == .address ? "IP Address" : "DNS Server", text: $value)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("Comment (optional)", text: $comment)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button(mode.isEditing ? "Save" : "Add") {
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
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 450, height: 350)
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
