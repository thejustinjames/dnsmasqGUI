import SwiftUI

@main
struct dnsmasqGUIApp: App {
    @StateObject private var configManager = ConfigManager()
    @StateObject private var dnsmasqService = DnsmasqService()
    @StateObject private var logReader = LogReader()
    @State private var showAbout = false
    @State private var showHelp = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(configManager)
                .environmentObject(dnsmasqService)
                .environmentObject(logReader)
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
                .sheet(isPresented: $showHelp) {
                    HelpView()
                }
        }
        .commands {
            // Replace About menu
            CommandGroup(replacing: .appInfo) {
                Button("About dnsmasqGUI") {
                    showAbout = true
                }
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("dnsmasqGUI Help") {
                    showHelp = true
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Link("GitHub Repository", destination: URL(string: "https://github.com/thejustinjames/dnsmasqGUI")!)

                Link("Report an Issue", destination: URL(string: "https://github.com/thejustinjames/dnsmasqGUI/issues")!)
            }

            // Service commands
            CommandGroup(after: .appSettings) {
                Button("Reload Configuration") {
                    Task {
                        await configManager.loadConfig()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Button("Start Service") {
                    Task {
                        await dnsmasqService.start()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Stop Service") {
                    Task {
                        await dnsmasqService.stop()
                    }
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])

                Button("Restart Service") {
                    Task {
                        await dnsmasqService.restart()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
