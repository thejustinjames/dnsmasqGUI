import SwiftUI

struct DHCPConfigView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedTab = 0
    @State private var isAddingRange = false
    @State private var isAddingHost = false
    @State private var isAddingOption = false
    @State private var leaseToDelete: DHCPLease?
    @State private var showDeleteConfirmation = false

    // Edit states
    @State private var rangeToEdit: (lease: DHCPLease, range: DHCPRange)?
    @State private var hostToEdit: (lease: DHCPLease, host: DHCPHost)?
    @State private var optionToEdit: (lease: DHCPLease, option: DHCPOption)?
    @State private var isEditingRange = false
    @State private var isEditingHost = false
    @State private var isEditingOption = false

    private var ranges: [DHCPLease] {
        configManager.config.dhcpLeases.filter {
            if case .range = $0.entryType { return true }
            return false
        }
    }

    private var hosts: [DHCPLease] {
        configManager.config.dhcpLeases.filter {
            if case .host = $0.entryType { return true }
            return false
        }
    }

    private var options: [DHCPLease] {
        configManager.config.dhcpLeases.filter {
            if case .option = $0.entryType { return true }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("DHCP Configuration")
                    .font(.headline)

                Spacer()

                if configManager.hasUnsavedChanges {
                    Text("Unsaved Changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Menu {
                    Button("Add DHCP Range") { isAddingRange = true }
                    Button("Add Static Host") { isAddingHost = true }
                    Button("Add DHCP Option") { isAddingOption = true }
                } label: {
                    Label("Add", systemImage: "plus")
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

            // Tabs
            Picker("", selection: $selectedTab) {
                Text("Ranges (\(ranges.count))").tag(0)
                Text("Static Hosts (\(hosts.count))").tag(1)
                Text("Options (\(options.count))").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            if configManager.isLoading {
                Spacer()
                ProgressView("Loading configuration...")
                Spacer()
            } else {
                TabView(selection: $selectedTab) {
                    DHCPRangeList(ranges: ranges, onEdit: { lease, range in
                        rangeToEdit = (lease, range)
                        isEditingRange = true
                    }, onDelete: { lease in
                        leaseToDelete = lease
                        showDeleteConfirmation = true
                    })
                    .tag(0)

                    DHCPHostList(hosts: hosts, onEdit: { lease, host in
                        hostToEdit = (lease, host)
                        isEditingHost = true
                    }, onDelete: { lease in
                        leaseToDelete = lease
                        showDeleteConfirmation = true
                    })
                    .tag(1)

                    DHCPOptionList(options: options, onEdit: { lease, option in
                        optionToEdit = (lease, option)
                        isEditingOption = true
                    }, onDelete: { lease in
                        leaseToDelete = lease
                        showDeleteConfirmation = true
                    })
                    .tag(2)
                }
                .tabViewStyle(.automatic)
            }
        }
        // Add sheets
        .sheet(isPresented: $isAddingRange) {
            DHCPRangeEditor(mode: .add) { range in
                configManager.addDHCPLease(DHCPLease(entryType: .range(range)))
            }
        }
        .sheet(isPresented: $isAddingHost) {
            DHCPHostEditor(mode: .add) { host in
                configManager.addDHCPLease(DHCPLease(entryType: .host(host)))
            }
        }
        .sheet(isPresented: $isAddingOption) {
            DHCPOptionEditor(mode: .add) { option in
                configManager.addDHCPLease(DHCPLease(entryType: .option(option)))
            }
        }
        // Edit sheets
        .sheet(isPresented: $isEditingRange) {
            if let edit = rangeToEdit {
                DHCPRangeEditor(mode: .edit(edit.range)) { updatedRange in
                    let updatedLease = DHCPLease(id: edit.lease.id, entryType: .range(updatedRange))
                    configManager.updateDHCPLease(updatedLease)
                }
            }
        }
        .sheet(isPresented: $isEditingHost) {
            if let edit = hostToEdit {
                DHCPHostEditor(mode: .edit(edit.host)) { updatedHost in
                    let updatedLease = DHCPLease(id: edit.lease.id, entryType: .host(updatedHost))
                    configManager.updateDHCPLease(updatedLease)
                }
            }
        }
        .sheet(isPresented: $isEditingOption) {
            if let edit = optionToEdit {
                DHCPOptionEditor(mode: .edit(edit.option)) { updatedOption in
                    let updatedLease = DHCPLease(id: edit.lease.id, entryType: .option(updatedOption))
                    configManager.updateDHCPLease(updatedLease)
                }
            }
        }
        .alert("Delete Entry", isPresented: $showDeleteConfirmation, presenting: leaseToDelete) { lease in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                configManager.deleteDHCPLease(lease)
            }
        } message: { _ in
            Text("Are you sure you want to delete this DHCP entry?")
        }
    }
}

// MARK: - Range List

struct DHCPRangeList: View {
    let ranges: [DHCPLease]
    let onEdit: (DHCPLease, DHCPRange) -> Void
    let onDelete: (DHCPLease) -> Void

    var body: some View {
        if ranges.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No DHCP ranges configured")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(ranges) { lease in
                    if case .range(let range) = lease.entryType {
                        DHCPRangeRow(range: range, onEdit: {
                            onEdit(lease, range)
                        })
                        .contextMenu {
                            Button("Edit") {
                                onEdit(lease, range)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                onDelete(lease)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

struct DHCPRangeRow: View {
    let range: DHCPRange
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(range.startIP) - \(range.endIP)")
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()

                    Text(range.leaseTime)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }

                if let netmask = range.netmask {
                    Text("Netmask: \(netmask)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let comment = range.comment {
                    Text(comment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onEdit()
        }
    }
}

// MARK: - Host List

struct DHCPHostList: View {
    let hosts: [DHCPLease]
    let onEdit: (DHCPLease, DHCPHost) -> Void
    let onDelete: (DHCPLease) -> Void

    var body: some View {
        if hosts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "desktopcomputer")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No static hosts configured")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(hosts) { lease in
                    if case .host(let host) = lease.entryType {
                        DHCPHostRow(host: host, onEdit: {
                            onEdit(lease, host)
                        })
                        .contextMenu {
                            Button("Edit") {
                                onEdit(lease, host)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                onDelete(lease)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

struct DHCPHostRow: View {
    let host: DHCPHost
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let hostname = host.hostname {
                        Text(hostname)
                            .font(.body)
                            .fontWeight(.medium)
                    } else {
                        Text(host.macAddress)
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Text(host.ipAddress)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }

                Text(host.macAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let comment = host.comment {
                    Text(comment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onEdit()
        }
    }
}

// MARK: - Option List

struct DHCPOptionList: View {
    let options: [DHCPLease]
    let onEdit: (DHCPLease, DHCPOption) -> Void
    let onDelete: (DHCPLease) -> Void

    var body: some View {
        if options.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "slider.horizontal.3")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("No DHCP options configured")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(options) { lease in
                    if case .option(let option) = lease.entryType {
                        DHCPOptionRow(option: option, onEdit: {
                            onEdit(lease, option)
                        })
                        .contextMenu {
                            Button("Edit") {
                                onEdit(lease, option)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                onDelete(lease)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

struct DHCPOptionRow: View {
    let option: DHCPOption
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(option.optionName)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()

                    Text("Option \(option.optionNumber)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                }

                Text(option.value)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let comment = option.comment {
                    Text(comment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onEdit()
        }
    }
}

// MARK: - Editors

struct DHCPRangeEditor: View {
    enum Mode {
        case add
        case edit(DHCPRange)

        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    let mode: Mode
    let onSave: (DHCPRange) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var startIP = ""
    @State private var endIP = ""
    @State private var netmask = ""
    @State private var leaseTime = "12h"
    @State private var comment = ""

    init(mode: Mode, onSave: @escaping (DHCPRange) -> Void) {
        self.mode = mode
        self.onSave = onSave

        if case .edit(let range) = mode {
            _startIP = State(initialValue: range.startIP)
            _endIP = State(initialValue: range.endIP)
            _netmask = State(initialValue: range.netmask ?? "")
            _leaseTime = State(initialValue: range.leaseTime)
            _comment = State(initialValue: range.comment ?? "")
        }
    }

    private var isValid: Bool {
        !startIP.isEmpty && !endIP.isEmpty && !leaseTime.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(mode.isEditing ? "Edit DHCP Range" : "Add DHCP Range")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                TextField("Start IP", text: $startIP)
                    .textFieldStyle(.roundedBorder)
                TextField("End IP", text: $endIP)
                    .textFieldStyle(.roundedBorder)
                TextField("Netmask (optional)", text: $netmask)
                    .textFieldStyle(.roundedBorder)
                TextField("Lease Time (e.g., 12h, 1d)", text: $leaseTime)
                    .textFieldStyle(.roundedBorder)
                TextField("Comment (optional)", text: $comment)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button(mode.isEditing ? "Save" : "Add") {
                    let range = DHCPRange(
                        startIP: startIP,
                        endIP: endIP,
                        leaseTime: leaseTime,
                        netmask: netmask.isEmpty ? nil : netmask,
                        comment: comment.isEmpty ? nil : comment
                    )
                    onSave(range)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
}

struct DHCPHostEditor: View {
    enum Mode {
        case add
        case edit(DHCPHost)

        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    let mode: Mode
    let onSave: (DHCPHost) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var macAddress = ""
    @State private var ipAddress = ""
    @State private var hostname = ""
    @State private var leaseTime = ""
    @State private var comment = ""

    init(mode: Mode, onSave: @escaping (DHCPHost) -> Void) {
        self.mode = mode
        self.onSave = onSave

        if case .edit(let host) = mode {
            _macAddress = State(initialValue: host.macAddress)
            _ipAddress = State(initialValue: host.ipAddress)
            _hostname = State(initialValue: host.hostname ?? "")
            _leaseTime = State(initialValue: host.leaseTime ?? "")
            _comment = State(initialValue: host.comment ?? "")
        }
    }

    private var isValid: Bool {
        !macAddress.isEmpty && !ipAddress.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(mode.isEditing ? "Edit Static Host" : "Add Static Host")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                TextField("MAC Address", text: $macAddress)
                    .textFieldStyle(.roundedBorder)
                TextField("IP Address", text: $ipAddress)
                    .textFieldStyle(.roundedBorder)
                TextField("Hostname (optional)", text: $hostname)
                    .textFieldStyle(.roundedBorder)
                TextField("Lease Time (optional)", text: $leaseTime)
                    .textFieldStyle(.roundedBorder)
                TextField("Comment (optional)", text: $comment)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button(mode.isEditing ? "Save" : "Add") {
                    let host = DHCPHost(
                        macAddress: macAddress,
                        ipAddress: ipAddress,
                        hostname: hostname.isEmpty ? nil : hostname,
                        leaseTime: leaseTime.isEmpty ? nil : leaseTime,
                        comment: comment.isEmpty ? nil : comment
                    )
                    onSave(host)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 380)
    }
}

struct DHCPOptionEditor: View {
    enum Mode {
        case add
        case edit(DHCPOption)

        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }
    }

    let mode: Mode
    let onSave: (DHCPOption) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedOption = 3
    @State private var customOption = ""
    @State private var value = ""
    @State private var comment = ""
    @State private var useCustomOption = false

    init(mode: Mode, onSave: @escaping (DHCPOption) -> Void) {
        self.mode = mode
        self.onSave = onSave

        if case .edit(let option) = mode {
            let isCommon = DHCPOption.commonOptions.contains { $0.0 == option.optionNumber }
            _useCustomOption = State(initialValue: !isCommon)
            _selectedOption = State(initialValue: isCommon ? option.optionNumber : 3)
            _customOption = State(initialValue: isCommon ? "" : String(option.optionNumber))
            _value = State(initialValue: option.value)
            _comment = State(initialValue: option.comment ?? "")
        }
    }

    private var optionNumber: Int {
        useCustomOption ? (Int(customOption) ?? 0) : selectedOption
    }

    private var isValid: Bool {
        optionNumber > 0 && !value.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(mode.isEditing ? "Edit DHCP Option" : "Add DHCP Option")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Toggle("Use Custom Option Number", isOn: $useCustomOption)

                if useCustomOption {
                    TextField("Option Number", text: $customOption)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Picker("Option", selection: $selectedOption) {
                        ForEach(DHCPOption.commonOptions, id: \.0) { option in
                            Text("\(option.0) - \(option.1)").tag(option.0)
                        }
                    }
                }

                TextField("Value", text: $value)
                    .textFieldStyle(.roundedBorder)

                TextField("Comment (optional)", text: $comment)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button(mode.isEditing ? "Save" : "Add") {
                    let option = DHCPOption(
                        optionNumber: optionNumber,
                        value: value,
                        comment: comment.isEmpty ? nil : comment
                    )
                    onSave(option)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 320)
    }
}

#Preview {
    DHCPConfigView()
        .environmentObject(ConfigManager())
}
