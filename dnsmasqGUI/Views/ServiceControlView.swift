import SwiftUI

struct ServiceControlView: View {
    @EnvironmentObject var dnsmasqService: DnsmasqService
    @EnvironmentObject var configManager: ConfigManager
    @State private var validationResult: (valid: Bool, message: String)?
    @State private var showValidationAlert = false

    var body: some View {
        VStack(spacing: 24) {
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

#Preview {
    ServiceControlView()
        .environmentObject(DnsmasqService())
        .environmentObject(ConfigManager())
}
