import SwiftUI

struct DHCPConfigView: View {
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedTab = 0
    @State private var isAddingRange = false
    @State private var isAddingHost = false
    @State private var isAddingOption = false
    @State private var leaseToDelete: DHCPLease?
    @State private var showDeleteConfirmation = false

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
                    DHCPRangeList(ranges: ranges, onDelete: { lease in
                        leaseToDelete = lease
                        showDeleteConfirmation = true
                    })
                    .tag(0)

                    DHCPHostList(hosts: hosts, onDelete: { lease in
                        leaseToDelete = lease
                        showDeleteConfirmation = true
                    })
                    .tag(1)

                    DHCPOptionList(options: options, onDelete: { lease in
                        leaseToDelete = lease
                        showDeleteConfirmation = true
                    })
                    .tag(2)
                }
                .tabViewStyle(.automatic)
            }
        }
        .sheet(isPresented: $isAddingRange) {
            DHCPRangeEditor { range in
                configManager.addDHCPLease(DHCPLease(entryType: .range(range)))
            }
        }
        .sheet(isPresented: $isAddingHost) {
            DHCPHostEditor { host in
                configManager.addDHCPLease(DHCPLease(entryType: .host(host)))
            }
        }
        .sheet(isPresented: $isAddingOption) {
            DHCPOptionEditor { option in
                configManager.addDHCPLease(DHCPLease(entryType: .option(option)))
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
                        DHCPRangeRow(range: range)
                            .contextMenu {
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

    var body: some View {
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
        .padding(.vertical, 4)
    }
}

// MARK: - Host List

struct DHCPHostList: View {
    let hosts: [DHCPLease]
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
                        DHCPHostRow(host: host)
                            .contextMenu {
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

    var body: some View {
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
        .padding(.vertical, 4)
    }
}

// MARK: - Option List

struct DHCPOptionList: View {
    let options: [DHCPLease]
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
                        DHCPOptionRow(option: option)
                            .contextMenu {
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

    var body: some View {
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
        .padding(.vertical, 4)
    }
}

// MARK: - Editors

struct DHCPRangeEditor: View {
    let onSave: (DHCPRange) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var startIP = ""
    @State private var endIP = ""
    @State private var netmask = ""
    @State private var leaseTime = "12h"
    @State private var comment = ""

    private var isValid: Bool {
        !startIP.isEmpty && !endIP.isEmpty && !leaseTime.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add DHCP Range")
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
                Button("Add") {
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
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 350)
    }
}

struct DHCPHostEditor: View {
    let onSave: (DHCPHost) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var macAddress = ""
    @State private var ipAddress = ""
    @State private var hostname = ""
    @State private var leaseTime = ""
    @State private var comment = ""

    private var isValid: Bool {
        !macAddress.isEmpty && !ipAddress.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Static Host")
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
                Button("Add") {
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
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 380)
    }
}

struct DHCPOptionEditor: View {
    let onSave: (DHCPOption) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedOption = 3
    @State private var customOption = ""
    @State private var value = ""
    @State private var comment = ""
    @State private var useCustomOption = false

    private var optionNumber: Int {
        useCustomOption ? (Int(customOption) ?? 0) : selectedOption
    }

    private var isValid: Bool {
        optionNumber > 0 && !value.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add DHCP Option")
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
                Button("Add") {
                    let option = DHCPOption(
                        optionNumber: optionNumber,
                        value: value,
                        comment: comment.isEmpty ? nil : comment
                    )
                    onSave(option)
                    dismiss()
                }
                .keyboardShortcut(.return)
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
