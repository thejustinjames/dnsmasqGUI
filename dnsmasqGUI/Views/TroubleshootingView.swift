import SwiftUI

struct TroubleshootingView: View {
    @State private var commandOutput: String = ""
    @State private var isRunning: Bool = false
    @State private var testDomain: String = ""
    @State private var grepPattern: String = ""
    @State private var showOutput: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Troubleshooting Tools")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quick Actions Section
                    ToolSection(title: "Quick Actions", icon: "bolt.fill") {
                        VStack(spacing: 12) {
                            ToolButton(
                                title: "Flush DNS Cache",
                                description: "Clear macOS DNS cache and restart mDNSResponder",
                                icon: "arrow.triangle.2.circlepath",
                                color: .blue
                            ) {
                                await runFlushDNS()
                            }

                            ToolButton(
                                title: "Create Resolver Directory",
                                description: "Create /etc/resolver if it doesn't exist",
                                icon: "folder.badge.plus",
                                color: .green
                            ) {
                                await runCreateResolverDir()
                            }

                            ToolButton(
                                title: "Restart dnsmasq",
                                description: "Restart dnsmasq via Homebrew services",
                                icon: "arrow.clockwise.circle",
                                color: .orange
                            ) {
                                await runRestartDnsmasq()
                            }

                            ToolButton(
                                title: "Check dnsmasq Status",
                                description: "Show current dnsmasq service status",
                                icon: "info.circle",
                                color: .purple
                            ) {
                                await runCheckStatus()
                            }
                        }
                    }

                    Divider()

                    // DNS Testing Section
                    ToolSection(title: "DNS Testing", icon: "network") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Test Domain Resolution")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                TextField("Enter domain (e.g., myapp.local)", text: $testDomain)
                                    .textFieldStyle(.roundedBorder)

                                Button("Test") {
                                    Task { await runDNSTest() }
                                }
                                .disabled(testDomain.isEmpty || isRunning)
                            }

                            HStack(spacing: 8) {
                                TestMethodButton(title: "dscacheutil", method: "dscacheutil") {
                                    await runDscacheutilTest()
                                }

                                TestMethodButton(title: "dig @127.0.0.1", method: "dig") {
                                    await runDigTest()
                                }

                                TestMethodButton(title: "nslookup", method: "nslookup") {
                                    await runNslookupTest()
                                }
                            }
                            .disabled(testDomain.isEmpty || isRunning)
                        }
                    }

                    Divider()

                    // Config Verification Section
                    ToolSection(title: "Configuration Verification", icon: "doc.text.magnifyingglass") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search dnsmasq.conf")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                TextField("Search pattern (e.g., domain name)", text: $grepPattern)
                                    .textFieldStyle(.roundedBorder)

                                Button("Search") {
                                    Task { await runGrepConfig() }
                                }
                                .disabled(grepPattern.isEmpty || isRunning)
                            }

                            HStack(spacing: 8) {
                                Button("View Full Config") {
                                    Task { await runViewConfig() }
                                }

                                Button("List Resolver Files") {
                                    Task { await runListResolvers() }
                                }

                                Button("Check Port 53") {
                                    Task { await runCheckPort53() }
                                }
                            }
                            .disabled(isRunning)
                        }
                    }

                    Divider()

                    // Output Section
                    ToolSection(title: "Command Output", icon: "terminal") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if isRunning {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Running...")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Clear") {
                                    commandOutput = ""
                                }
                                .disabled(commandOutput.isEmpty)

                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(commandOutput, forType: .string)
                                }
                                .disabled(commandOutput.isEmpty)
                            }

                            ScrollView {
                                Text(commandOutput.isEmpty ? "Run a command to see output here..." : commandOutput)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(commandOutput.isEmpty ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .frame(minHeight: 150, maxHeight: 300)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.textBackgroundColor))
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Command Functions

    private func runFlushDNS() async {
        await runCommand(
            "Flushing DNS cache...",
            command: "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo 'DNS cache flushed successfully'"
        )
    }

    private func runCreateResolverDir() async {
        await runCommand(
            "Creating resolver directory...",
            command: "sudo mkdir -p /etc/resolver && ls -la /etc/resolver 2>/dev/null || echo '/etc/resolver created (empty)'"
        )
    }

    private func runRestartDnsmasq() async {
        await runCommand(
            "Restarting dnsmasq...",
            command: "sudo brew services restart dnsmasq && sleep 1 && brew services list | grep dnsmasq"
        )
    }

    private func runCheckStatus() async {
        await runCommand(
            "Checking dnsmasq status...",
            command: "brew services list | grep dnsmasq; echo '---'; ps aux | grep '[d]nsmasq' || echo 'No dnsmasq process found'"
        )
    }

    private func runDNSTest() async {
        await runDscacheutilTest()
    }

    private func runDscacheutilTest() async {
        let domain = testDomain.trimmingCharacters(in: .whitespaces)
        await runCommand(
            "Testing DNS resolution for \(domain)...",
            command: "dscacheutil -q host -a name \(domain)"
        )
    }

    private func runDigTest() async {
        let domain = testDomain.trimmingCharacters(in: .whitespaces)
        await runCommand(
            "Testing DNS via dig @127.0.0.1 for \(domain)...",
            command: "dig @127.0.0.1 \(domain) +short; echo '---'; dig @127.0.0.1 \(domain)"
        )
    }

    private func runNslookupTest() async {
        let domain = testDomain.trimmingCharacters(in: .whitespaces)
        await runCommand(
            "Testing DNS via nslookup for \(domain)...",
            command: "nslookup \(domain) 127.0.0.1"
        )
    }

    private func runGrepConfig() async {
        let pattern = grepPattern.trimmingCharacters(in: .whitespaces)
        await runCommand(
            "Searching dnsmasq.conf for '\(pattern)'...",
            command: "grep -n '\(pattern)' /opt/homebrew/etc/dnsmasq.conf 2>/dev/null || grep -n '\(pattern)' /usr/local/etc/dnsmasq.conf 2>/dev/null || echo 'Pattern not found in config'"
        )
    }

    private func runViewConfig() async {
        await runCommand(
            "Viewing dnsmasq.conf...",
            command: "cat /opt/homebrew/etc/dnsmasq.conf 2>/dev/null || cat /usr/local/etc/dnsmasq.conf 2>/dev/null || echo 'Config file not found'"
        )
    }

    private func runListResolvers() async {
        await runCommand(
            "Listing resolver files...",
            command: "echo '=== /etc/resolver contents ===' && ls -la /etc/resolver 2>/dev/null || echo 'Directory not found'; echo ''; for f in /etc/resolver/*; do if [ -f \"$f\" ]; then echo \"=== $f ===\"; cat \"$f\"; echo ''; fi; done 2>/dev/null"
        )
    }

    private func runCheckPort53() async {
        await runCommand(
            "Checking port 53...",
            command: "sudo lsof -i :53 2>/dev/null || echo 'No process listening on port 53'"
        )
    }

    private func runCommand(_ description: String, command: String) async {
        isRunning = true
        commandOutput = "\(description)\n\n"

        do {
            let output = try await executeCommand(command)
            commandOutput += output
        } catch {
            commandOutput += "Error: \(error.localizedDescription)"
        }

        isRunning = false
    }

    private func executeCommand(_ command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Try with admin privileges via AppleScript
                let script = """
                    do shell script "\(command.replacingOccurrences(of: "\"", with: "\\\""))" with administrator privileges
                    """

                var error: NSDictionary?
                let appleScript = NSAppleScript(source: script)
                let result = appleScript?.executeAndReturnError(&error)

                if let appleScriptError = error {
                    // Try without admin privileges
                    let process = Process()
                    let pipe = Pipe()

                    process.executableURL = URL(fileURLWithPath: "/bin/bash")
                    process.arguments = ["-c", command.replacingOccurrences(of: "sudo ", with: "")]
                    process.standardOutput = pipe
                    process.standardError = pipe

                    do {
                        try process.run()
                        process.waitUntilExit()

                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8) ?? ""
                        continuation.resume(returning: output)
                    } catch let processError {
                        let message = appleScriptError[NSAppleScript.errorMessage] as? String ?? processError.localizedDescription
                        continuation.resume(throwing: NSError(domain: "TroubleshootingView", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
                    }
                } else {
                    continuation.resume(returning: result?.stringValue ?? "Command completed (no output)")
                }
            }
        }
    }
}

// MARK: - Helper Views

struct ToolSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }

            content()
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
        }
    }
}

struct ToolButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
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
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)

                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: icon)
                            .foregroundColor(color)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
    }
}

struct TestMethodButton: View {
    let title: String
    let method: String
    let action: () async -> Void

    var body: some View {
        Button(title) {
            Task { await action() }
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    TroubleshootingView()
}
