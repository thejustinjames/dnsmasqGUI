import SwiftUI
import ServiceManagement

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

struct SettingsView: View {
    @AppStorage("menuBarOnlyMode") private var menuBarOnly = false
    @AppStorage("launchAtStartup") private var launchAtStartup = false
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @State private var showingRestartAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Configure Handed preferences")
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                // Startup Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: $launchAtStartup) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Launch at Startup")
                                    .fontWeight(.medium)
                                Text("Automatically start Handed when you log in")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: launchAtStartup) { newValue in
                            updateLaunchAtStartup(enabled: newValue)
                        }

                        Divider()

                        Toggle(isOn: $menuBarOnly) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Menu Bar Only")
                                    .fontWeight(.medium)
                                Text("Hide the Dock icon and run only in the menu bar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: menuBarOnly) { newValue in
                            updateActivationPolicy(menuBarOnly: newValue)
                            showingRestartAlert = true
                        }
                    }
                    .padding(4)
                } label: {
                    Label("Startup", systemImage: "power")
                }

                // Appearance Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .fontWeight(.medium)

                        Picker("Appearance", selection: $appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                                Label(mode.rawValue, systemImage: mode.icon)
                                    .tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appearanceMode) { newValue in
                            updateAppearance(mode: AppearanceMode(rawValue: newValue) ?? .system)
                        }

                        Text("Choose how Handed appears. Select System to automatically match your Mac's appearance.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("Appearance", systemImage: "paintbrush.fill")
                }

                // Menu Bar Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "menubar.rectangle")
                                .font(.title2)
                                .foregroundColor(.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Menu Bar Access")
                                    .fontWeight(.medium)
                                Text("Handed always shows in the menu bar for quick access to start/stop dnsmasq, flush DNS cache, and check status.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 16) {
                            StatusIndicator(color: .green, label: "Running")
                            StatusIndicator(color: .gray, label: "Stopped")
                            StatusIndicator(color: .red, label: "Error")
                            StatusIndicator(color: .orange, label: "Unknown")
                        }
                        .padding(.top, 4)
                    }
                    .padding(4)
                } label: {
                    Label("Menu Bar", systemImage: "hand.raised.fill")
                }

                // About Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 48)

                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Handed")
                                    .font(.headline)
                                Text("Version \(AppInfo.version)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("A native macOS GUI for dnsmasq")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                        Divider()

                        HStack(spacing: 16) {
                            Link(destination: URL(string: "https://github.com/thejustinjames/handed")!) {
                                Label("GitHub", systemImage: "link")
                            }

                            Link(destination: URL(string: "https://github.com/thejustinjames/handed/issues")!) {
                                Label("Report Issue", systemImage: "exclamationmark.bubble")
                            }
                        }
                        .font(.caption)
                    }
                    .padding(4)
                } label: {
                    Label("About", systemImage: "info.circle")
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Restart Required", isPresented: $showingRestartAlert) {
            Button("OK") { }
        } message: {
            Text("The Dock icon change will take full effect after restarting Handed.")
        }
    }

    private func updateLaunchAtStartup(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at startup: \(error)")
        }
    }

    private func updateActivationPolicy(menuBarOnly: Bool) {
        if menuBarOnly {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }

    private func updateAppearance(mode: AppearanceMode) {
        switch mode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

struct StatusIndicator: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}
