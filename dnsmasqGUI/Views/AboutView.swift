import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text("JJ")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)

            // App Name & Version
            VStack(spacing: 4) {
                Text("dnsmasqGUI")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version \(AppInfo.version) (\(AppInfo.build))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Description
            Text("A native macOS GUI for managing dnsmasq")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .padding(.horizontal, 40)

            // Credits
            VStack(spacing: 8) {
                Text("Created by Justin James")
                    .font(.callout)

                Link("GitHub Repository", destination: URL(string: "https://github.com/thejustinjames/dnsmasqGUI")!)
                    .font(.callout)
            }

            Spacer()

            // Copyright
            Text("© 2026 Justin James. MIT License.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.escape)
            .padding(.bottom)
        }
        .padding()
        .frame(width: 350, height: 400)
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("dnsmasqGUI Help")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HelpSection(
                        title: "Getting Started",
                        icon: "play.circle",
                        content: """
                        1. Install dnsmasq via Homebrew: brew install dnsmasq
                        2. Use Service Control to start/stop dnsmasq
                        3. Add DNS records to override domain resolution
                        4. Save changes and restart the service
                        """
                    )

                    HelpSection(
                        title: "DNS Configuration",
                        icon: "network",
                        content: """
                        • Address Override: Map a domain to a specific IP
                        • Upstream Server: Route queries to specific DNS
                        • Local Only: Answer from local config only

                        Click + to add, pencil to edit, or right-click for options.
                        Use the Test button to verify DNS resolution.
                        """
                    )

                    HelpSection(
                        title: "DHCP Configuration",
                        icon: "server.rack",
                        content: """
                        • Ranges: Define DHCP IP address pools
                        • Static Hosts: Assign fixed IPs to MAC addresses
                        • Options: Configure gateway, DNS, etc.

                        Changes require saving and restarting the service.
                        """
                    )

                    HelpSection(
                        title: "Service Control",
                        icon: "gearshape.2",
                        content: """
                        Two execution modes:
                        • Homebrew Services: Persistent, auto-starts on boot
                        • Local Process: Manual control, no persistence

                        Use Settings to configure custom paths.
                        """
                    )

                    HelpSection(
                        title: "Log Viewer",
                        icon: "doc.text.magnifyingglass",
                        content: """
                        View dnsmasq logs in real-time.
                        • Use the search box to filter entries
                        • Enable Auto-scroll to follow new logs
                        • Export logs for troubleshooting
                        """
                    )

                    HelpSection(
                        title: "Keyboard Shortcuts",
                        icon: "keyboard",
                        content: """
                        ⌘R - Reload Configuration
                        ⇧⌘S - Start Service
                        ⇧⌘X - Stop Service
                        ⇧⌘R - Restart Service
                        """
                    )

                    HelpSection(
                        title: "Troubleshooting",
                        icon: "wrench.and.screwdriver",
                        content: """
                        • Service won't start? Check port 53 conflicts
                        • No logs? Enable logging in dnsmasq.conf
                        • Permission errors? Grant automation access

                        Config file: /opt/homebrew/etc/dnsmasq.conf
                        """
                    )
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }
}

struct HelpSection: View {
    let title: String
    let icon: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }

            Text(content)
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// App version info
struct AppInfo {
    static let version = "1.0.0"
    static let build = "1"
    static let name = "dnsmasqGUI"
    static let author = "Justin James"
}

#Preview {
    AboutView()
}

#Preview("Help") {
    HelpView()
}
