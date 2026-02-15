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
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)

            // App Name & Version
            VStack(spacing: 4) {
                Text("Handed")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version \(AppInfo.version) (\(AppInfo.build))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Description
            Text("A native macOS GUI for managing dnsmasq and DNS resolvers")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .padding(.horizontal, 40)

            // Credits
            VStack(spacing: 8) {
                Text("Created by Justin James")
                    .font(.callout)

                Link("GitHub Repository", destination: URL(string: "https://github.com/thejustinjames/handed")!)
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
                Text("Handed Help")
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
                        4. Configure resolver files to route DNS queries
                        5. Save changes and restart the service
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
                        title: "Resolver Files",
                        icon: "folder.badge.gearshape",
                        content: """
                        Manage macOS resolver files in /etc/resolver:
                        • Route specific domains to custom DNS servers
                        • Point .local, .test, etc. to 127.0.0.1

                        Create files like /etc/resolver/local to route
                        all *.local queries to your local dnsmasq.

                        Example: /etc/resolver/mycompany.cloud
                        → Routes all *.mycompany.cloud to 127.0.0.1
                        """
                    )

                    HelpSection(
                        title: "Quick Setup Guide",
                        icon: "list.number",
                        content: """
                        Complete setup in 5 steps:

                        1. Install dnsmasq:
                           brew install dnsmasq

                        2. Add DNS records in DNS Configuration
                           (address=/mydomain.local/127.0.0.1)

                        3. Create resolver file in Resolver Files
                           (/etc/resolver/mydomain.local → 127.0.0.1)

                        4. Start dnsmasq via Service Control

                        5. Flush DNS cache in Troubleshooting
                           (or run: sudo dscacheutil -flushcache)
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
                        Common issues and solutions:

                        DNS not resolving?
                        1. Flush DNS cache (Troubleshooting → Flush DNS)
                        2. Verify dnsmasq is running (check Service Control)
                        3. Check resolver file exists for your domain
                        4. Test with: dig @127.0.0.1 yourdomain.local

                        Service won't start?
                        • Check port 53: sudo lsof -i :53
                        • Stop conflicting services first

                        Testing DNS resolution:
                        • dscacheutil -q host -a name yourdomain.local
                        • dig @127.0.0.1 yourdomain.local
                        • nslookup yourdomain.local 127.0.0.1

                        Config: /opt/homebrew/etc/dnsmasq.conf
                        Resolvers: /etc/resolver/
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
    static let version = "2.0.0"
    static let build = "1"
    static let name = "Handed"
    static let author = "Justin James"
}

#Preview {
    AboutView()
}

#Preview("Help") {
    HelpView()
}
