import SwiftUI

@main
struct dnsmasqGUIApp: App {
    @StateObject private var configManager = ConfigManager()
    @StateObject private var dnsmasqService = DnsmasqService()
    @StateObject private var logReader = LogReader()
    @State private var showAbout = false
    @State private var showHelp = false

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
                .onAppear {
                    // Initialize menu bar with dnsmasq service
                    appDelegate.setupMenuBar(dnsmasqService: dnsmasqService)
                }
        }
        .commands {
            // Replace About menu
            CommandGroup(replacing: .appInfo) {
                Button("About Handed") {
                    showAbout = true
                }
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("Handed Help") {
                    showHelp = true
                }
                .keyboardShortcut("?", modifiers: [.command])

                Divider()

                Link("GitHub Repository", destination: URL(string: "https://github.com/thejustinjames/handed")!)

                Link("Report an Issue", destination: URL(string: "https://github.com/thejustinjames/handed/issues")!)
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

/// AppDelegate for handling menu bar and other AppKit integrations
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var dnsmasqService: DnsmasqService?
    private var statusObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar will be set up when ContentView appears
    }

    func setupMenuBar(dnsmasqService: DnsmasqService) {
        self.dnsmasqService = dnsmasqService

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        updateStatusButton()
        setupMenu()

        // Observe status changes
        statusObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DnsmasqStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusButton()
                self?.setupMenu()
            }
        }

        // Initial status check
        Task { @MainActor in
            await dnsmasqService.checkStatus()
            updateStatusButton()
            setupMenu()
        }
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let state = dnsmasqService?.status.state ?? .unknown

        let imageName: String
        let tintColor: NSColor

        switch state {
        case .running:
            imageName = "hand.raised.fill"
            tintColor = .systemGreen
        case .stopped:
            imageName = "hand.raised"
            tintColor = .systemGray
        case .error:
            imageName = "hand.raised.slash.fill"
            tintColor = .systemRed
        case .unknown:
            imageName = "hand.raised"
            tintColor = .systemOrange
        }

        if let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Handed") {
            let coloredImage = image.withSymbolConfiguration(config)
            button.image = coloredImage
            button.contentTintColor = tintColor
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        let state = dnsmasqService?.status.state ?? .unknown

        // Status header
        let statusText: String
        switch state {
        case .running:
            statusText = "● dnsmasq is running"
        case .stopped:
            statusText = "○ dnsmasq is stopped"
        case .error:
            statusText = "✕ dnsmasq error"
        case .unknown:
            statusText = "? dnsmasq status unknown"
        }

        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Service controls
        let startItem = NSMenuItem(title: "Start dnsmasq", action: #selector(startService), keyEquivalent: "")
        startItem.target = self
        startItem.isEnabled = state != .running
        menu.addItem(startItem)

        let stopItem = NSMenuItem(title: "Stop dnsmasq", action: #selector(stopService), keyEquivalent: "")
        stopItem.target = self
        stopItem.isEnabled = state == .running
        menu.addItem(stopItem)

        let restartItem = NSMenuItem(title: "Restart dnsmasq", action: #selector(restartService), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)

        menu.addItem(NSMenuItem.separator())

        // Quick actions
        let flushItem = NSMenuItem(title: "Flush DNS Cache", action: #selector(flushDNSCache), keyEquivalent: "")
        flushItem.target = self
        menu.addItem(flushItem)

        let refreshItem = NSMenuItem(title: "Refresh Status", action: #selector(refreshStatus), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        // Open main window
        let openItem = NSMenuItem(title: "Open Handed", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Handed", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func startService() {
        Task { @MainActor in
            await dnsmasqService?.start()
            updateStatusButton()
            setupMenu()
        }
    }

    @objc private func stopService() {
        Task { @MainActor in
            await dnsmasqService?.stop()
            updateStatusButton()
            setupMenu()
        }
    }

    @objc private func restartService() {
        Task { @MainActor in
            await dnsmasqService?.restart()
            updateStatusButton()
            setupMenu()
        }
    }

    @objc private func flushDNSCache() {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
                do shell script "dscacheutil -flushcache && killall -HUP mDNSResponder" with administrator privileges
                """
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&error)

            DispatchQueue.main.async {
                if error == nil {
                    self.showNotification(title: "DNS Cache Flushed", message: "DNS cache has been cleared successfully")
                }
            }
        }
    }

    @objc private func refreshStatus() {
        Task { @MainActor in
            await dnsmasqService?.checkStatus()
            updateStatusButton()
            setupMenu()
        }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible || $0.isMiniaturized }) {
            window.makeKeyAndOrderFront(nil)
            window.deminiaturize(nil)
        } else if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func showNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}

import UserNotifications
