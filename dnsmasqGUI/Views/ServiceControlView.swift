import SwiftUI

struct ServiceControlView: View {
    @EnvironmentObject var dnsmasqService: DnsmasqService
    @EnvironmentObject var configManager: ConfigManager
    @State private var validationResult: (valid: Bool, message: String)?
    @State private var showValidationAlert = false
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Mode Selection Card
                VStack(spacing: 16) {
                    HStack {
                        Text("Execution Mode")
                            .font(.headline)
                        Spacer()
                        Button(action: { showSettings.toggle() }) {
                            Label("Settings", systemImage: "gear")
                        }
                    }

                    Picker("Mode", selection: $dnsmasqService.mode) {
                        ForEach(DnsmasqMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(dnsmasqService.mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                )

                // Status Card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: dnsmasqService.status.state.icon)
                            .font(.system(size: 48))
                            .foregroundColor(statusColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("dnsmasq Service")
                                .font(.headline)

                            Text(dnsmasqService.status.state.rawValue)
                                .font(.title2)
                                .foregroundColor(statusColor)

                            if let pid = dnsmasqService.status.pid {
                                Text("PID: \(pid)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("Mode: \(dnsmasqService.mode.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let error = dnsmasqService.status.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(statusColor.opacity(0.1))
                    )

                    // Control Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await dnsmasqService.start()
                            }
                        }) {
                            Label("Start", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(dnsmasqService.isProcessing || dnsmasqService.status.state == .running)

                        Button(action: {
                            Task {
                                await dnsmasqService.stop()
                            }
                        }) {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(dnsmasqService.isProcessing || dnsmasqService.status.state == .stopped)

                        Button(action: {
                            Task {
                                await dnsmasqService.restart()
                            }
                        }) {
                            Label("Restart", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(dnsmasqService.isProcessing)
                    }

                    if dnsmasqService.isProcessing {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                )

                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await dnsmasqService.checkStatus()
                            }
                        }) {
                            Label("Refresh Status", systemImage: "arrow.clockwise")
                        }

                        Button(action: {
                            Task {
                                validationResult = await dnsmasqService.validateConfig()
                                showValidationAlert = true
                            }
                        }) {
                            Label("Validate Config", systemImage: "checkmark.shield")
                        }

                        if configManager.hasUnsavedChanges {
                            Button(action: {
                                Task {
                                    if await configManager.saveConfig() {
                                        await dnsmasqService.restart()
                                    }
                                }
                            }) {
                                Label("Save & Restart", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                )

                // Paths Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paths")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("dnsmasq binary:")
                                .foregroundColor(.secondary)
                            Text(dnsmasqService.dnsmasqPath)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            if FileManager.default.fileExists(atPath: dnsmasqService.dnsmasqPath) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }

                        HStack {
                            Text("Config file:")
                                .foregroundColor(.secondary)
                            Text(dnsmasqService.configPath)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            if FileManager.default.fileExists(atPath: dnsmasqService.configPath) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                )

                // Output Log
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output")
                        .font(.headline)

                    ScrollView {
                        Text(dnsmasqService.lastOutput.isEmpty ? "No output" : dnsmasqService.lastOutput)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(dnsmasqService.lastOutput.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.textBackgroundColor))
                    )
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                )

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            ServiceSettingsView()
        }
        .alert("Configuration Validation", isPresented: $showValidationAlert, presenting: validationResult) { _ in
            Button("OK", role: .cancel) { }
        } message: { result in
            if result.valid {
                Text("Configuration is valid and ready to use.")
            } else {
                Text("Validation failed: \(result.message)")
            }
        }
    }

    private var statusColor: Color {
        switch dnsmasqService.status.state {
        case .running: return .green
        case .stopped: return .gray
        case .error: return .red
        case .unknown: return .orange
        }
    }
}

struct ServiceSettingsView: View {
    @EnvironmentObject var dnsmasqService: DnsmasqService
    @Environment(\.dismiss) private var dismiss

    @State private var dnsmasqPath: String = ""
    @State private var configPath: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Service Settings")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section("Paths") {
                    HStack {
                        TextField("dnsmasq Binary Path", text: $dnsmasqPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse") {
                            browsePath(for: .binary)
                        }
                    }

                    HStack {
                        TextField("Config File Path", text: $configPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse") {
                            browsePath(for: .config)
                        }
                    }
                }

                Section("Execution Mode") {
                    Picker("Mode", selection: $dnsmasqService.mode) {
                        ForEach(DnsmasqMode.allCases) { mode in
                            VStack(alignment: .leading) {
                                Text(mode.rawValue)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("Mode Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Homebrew Services")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Uses 'brew services' to manage dnsmasq. The service will start automatically on boot and is managed by launchd.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        Text("Local Process")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Runs dnsmasq directly as a process. You have full control but the service won't persist after reboot unless you start it again.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()

            Divider()

            HStack {
                Button("Reset to Defaults") {
                    dnsmasqPath = "/opt/homebrew/sbin/dnsmasq"
                    configPath = "/opt/homebrew/etc/dnsmasq.conf"
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    dnsmasqService.dnsmasqPath = dnsmasqPath
                    dnsmasqService.configPath = configPath
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onAppear {
            dnsmasqPath = dnsmasqService.dnsmasqPath
            configPath = dnsmasqService.configPath
        }
    }

    enum PathType {
        case binary
        case config
    }

    private func browsePath(for type: PathType) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        switch type {
        case .binary:
            panel.message = "Select dnsmasq binary"
            panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/sbin")
        case .config:
            panel.message = "Select dnsmasq configuration file"
            panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/etc")
            panel.allowedContentTypes = [.text, .plainText]
        }

        if panel.runModal() == .OK, let url = panel.url {
            switch type {
            case .binary:
                dnsmasqPath = url.path
            case .config:
                configPath = url.path
            }
        }
    }
}

#Preview {
    ServiceControlView()
        .environmentObject(DnsmasqService())
        .environmentObject(ConfigManager())
}
