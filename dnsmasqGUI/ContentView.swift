import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dns = "DNS Configuration"
    case dhcp = "DHCP Configuration"
    case service = "Service Control"
    case logs = "Log Viewer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dns: return "network"
        case .dhcp: return "server.rack"
        case .service: return "gearshape.2"
        case .logs: return "doc.text.magnifyingglass"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .dns
    @EnvironmentObject var configManager: ConfigManager
    @EnvironmentObject var dnsmasqService: DnsmasqService

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(NavigationItem.allCases, selection: $selectedItem) { item in
                    NavigationLink(value: item) {
                        Label(item.rawValue, systemImage: item.icon)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                // Footer with logo and version
                HStack(spacing: 8) {
                    // Mini JJ Logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)

                        Text("JJ")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("dnsmasqGUI")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("v\(AppInfo.version)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Status indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
            .frame(minWidth: 200)
        } detail: {
            Group {
                switch selectedItem {
                case .dns:
                    DNSConfigView()
                case .dhcp:
                    DHCPConfigView()
                case .service:
                    ServiceControlView()
                case .logs:
                    LogViewerView()
                case .none:
                    WelcomeView()
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .frame(minWidth: 700, minHeight: 500)
        .task {
            await configManager.loadConfig()
            await dnsmasqService.checkStatus()
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

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Text("JJ")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)

            VStack(spacing: 8) {
                Text("dnsmasqGUI")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Version \(AppInfo.version)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("Select an option from the sidebar to get started")
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            VStack(alignment: .leading, spacing: 12) {
                QuickTip(icon: "network", title: "DNS Configuration", description: "Manage DNS records and overrides")
                QuickTip(icon: "server.rack", title: "DHCP Configuration", description: "Configure IP ranges and static leases")
                QuickTip(icon: "gearshape.2", title: "Service Control", description: "Start, stop, and monitor dnsmasq")
                QuickTip(icon: "doc.text.magnifyingglass", title: "Log Viewer", description: "View real-time DNS/DHCP logs")
            }
        }
        .padding(40)
    }
}

struct QuickTip: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ConfigManager())
        .environmentObject(DnsmasqService())
        .environmentObject(LogReader())
}
