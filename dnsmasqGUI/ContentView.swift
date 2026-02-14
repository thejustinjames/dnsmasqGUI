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
            List(NavigationItem.allCases, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .listStyle(.sidebar)
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
                    Text("Select an item from the sidebar")
                        .foregroundColor(.secondary)
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
}

#Preview {
    ContentView()
        .environmentObject(ConfigManager())
        .environmentObject(DnsmasqService())
        .environmentObject(LogReader())
}
