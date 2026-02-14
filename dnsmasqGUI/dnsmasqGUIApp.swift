import SwiftUI

@main
struct dnsmasqGUIApp: App {
    @StateObject private var configManager = ConfigManager()
    @StateObject private var dnsmasqService = DnsmasqService()
    @StateObject private var logReader = LogReader()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(configManager)
                .environmentObject(dnsmasqService)
                .environmentObject(logReader)
        }
        .commands {
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
