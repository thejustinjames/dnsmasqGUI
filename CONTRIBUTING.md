# Developer Guide

This guide covers the architecture, codebase structure, and development workflow for contributing to dnsmasqGUI.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Development Setup](#development-setup)
- [Code Architecture](#code-architecture)
- [Adding Features](#adding-features)
- [Testing](#testing)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)

## Architecture Overview

dnsmasqGUI follows the **MVVM (Model-View-ViewModel)** pattern with SwiftUI:

```
┌─────────────────────────────────────────────────────────────┐
│                         Views                                │
│  (DNSConfigView, DHCPConfigView, ServiceControlView, etc.)  │
└─────────────────────────┬───────────────────────────────────┘
                          │ @EnvironmentObject
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Services (ViewModels)                     │
│      (ConfigManager, DnsmasqService, LogReader)             │
│                    @Published properties                     │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                        Models                                │
│    (DNSRecord, DHCPLease, DnsmasqConfig, ServiceStatus)     │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    System Layer                              │
│   (dnsmasq.conf file, brew services, log files)             │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
dnsmasqGUI/
├── dnsmasqGUI.xcodeproj/       # Xcode project file
├── dnsmasqGUI/
│   ├── dnsmasqGUIApp.swift     # App entry point, menu commands
│   ├── ContentView.swift        # Main window, sidebar navigation
│   │
│   ├── Models/                  # Data models
│   │   ├── DNSRecord.swift      # DNS entry (address, server, local)
│   │   ├── DHCPLease.swift      # DHCP entries (range, host, option)
│   │   ├── DnsmasqConfig.swift  # Full config parser/serializer
│   │   └── ServiceStatus.swift  # Service state representation
│   │
│   ├── Views/                   # SwiftUI views
│   │   ├── DNSConfigView.swift      # DNS management UI
│   │   ├── DHCPConfigView.swift     # DHCP management UI
│   │   ├── ServiceControlView.swift # Service control UI
│   │   └── LogViewerView.swift      # Log monitoring UI
│   │
│   ├── Services/                # Business logic / ViewModels
│   │   ├── ConfigManager.swift  # Config file read/write
│   │   ├── DnsmasqService.swift # Homebrew service control
│   │   └── LogReader.swift      # Log file monitoring
│   │
│   ├── Assets.xcassets/         # App icons, colors
│   └── dnsmasqGUI.entitlements  # App permissions
│
├── LICENSE
├── README.md
└── CONTRIBUTING.md
```

## Development Setup

### Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+
- Homebrew with dnsmasq installed

### Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/dnsmasqGUI.git
   cd dnsmasqGUI
   ```

2. **Open in Xcode**
   ```bash
   open dnsmasqGUI.xcodeproj
   ```

3. **Select the dnsmasqGUI scheme** and your Mac as the run destination

4. **Build and run** with `Cmd + R`

### Development Tips

- Use SwiftUI Previews (`Cmd + Option + P`) for rapid UI iteration
- The app requires dnsmasq to be installed for full functionality
- Test privilege escalation by running the built app outside Xcode

## Code Architecture

### Models

#### DNSRecord.swift
Represents DNS configuration entries:

```swift
struct DNSRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var recordType: RecordType  // .address, .server, .local
    var domain: String
    var value: String
    var comment: String?

    // Parse from config line: "address=/example.com/192.168.1.1"
    static func fromConfigLine(_ line: String) -> DNSRecord?

    // Convert to config line format
    func toConfigLine() -> String
}
```

#### DHCPLease.swift
Contains three DHCP entry types:

```swift
struct DHCPRange   // dhcp-range=start,end,lease-time
struct DHCPHost    // dhcp-host=mac,ip,hostname
struct DHCPOption  // dhcp-option=number,value

struct DHCPLease: Identifiable {
    let id: UUID
    var entryType: EntryType  // .range, .host, .option
}
```

#### DnsmasqConfig.swift
Full configuration parser that preserves formatting:

```swift
struct DnsmasqConfig {
    var dnsRecords: [DNSRecord]
    var dhcpLeases: [DHCPLease]
    var rawLines: [ConfigLine]  // Preserves comments, whitespace

    static func parse(from content: String) -> DnsmasqConfig
    func toConfigString() -> String
}
```

### Services (ViewModels)

All services are `@MainActor` classes with `@Published` properties for SwiftUI binding.

#### ConfigManager.swift
Manages the dnsmasq.conf file:

```swift
@MainActor
class ConfigManager: ObservableObject {
    @Published var config: DnsmasqConfig
    @Published var isLoading: Bool
    @Published var hasUnsavedChanges: Bool

    func loadConfig() async
    func saveConfig() async -> Bool
    func addDNSRecord(_ record: DNSRecord)
    func updateDNSRecord(_ record: DNSRecord)
    func deleteDNSRecord(_ record: DNSRecord)
}
```

#### DnsmasqService.swift
Controls the dnsmasq service via Homebrew:

```swift
@MainActor
class DnsmasqService: ObservableObject {
    @Published var status: ServiceStatus
    @Published var isProcessing: Bool

    func start() async
    func stop() async
    func restart() async
    func checkStatus() async
    func validateConfig() async -> (valid: Bool, message: String)
}
```

#### LogReader.swift
Monitors log files using DispatchSource:

```swift
@MainActor
class LogReader: ObservableObject {
    @Published var logLines: [LogLine]
    @Published var isMonitoring: Bool

    func startMonitoring()
    func stopMonitoring()
    func clearLogs()
    func exportLogs() -> String
}
```

### Views

Views use `@EnvironmentObject` to access services:

```swift
struct DNSConfigView: View {
    @EnvironmentObject var configManager: ConfigManager

    var body: some View {
        // UI implementation
    }
}
```

### Privilege Escalation

Admin operations use AppleScript for privilege escalation:

```swift
private func runAppleScript(_ script: String) async throws -> String {
    let script = """
        do shell script "\(command)" with administrator privileges
        """
    // Execute via NSAppleScript
}
```

## Adding Features

### Adding a New DNS Record Type

1. **Update the model** (`DNSRecord.swift`):
   ```swift
   enum RecordType: String, Codable, CaseIterable {
       case address = "address"
       case server = "server"
       case local = "local"
       case cname = "cname"  // New type
   }
   ```

2. **Update parsing** in `fromConfigLine()`:
   ```swift
   if mainPart.hasPrefix("cname=") {
       // Parse cname=alias,target
   }
   ```

3. **Update serialization** in `toConfigLine()`:
   ```swift
   case .cname:
       line = "cname=\(domain),\(value)"
   ```

4. **Update the UI** (`DNSConfigView.swift`) if needed

### Adding a New View

1. **Create the view file** in `Views/`:
   ```swift
   struct NewFeatureView: View {
       @EnvironmentObject var configManager: ConfigManager

       var body: some View {
           // Implementation
       }
   }
   ```

2. **Add to navigation** (`ContentView.swift`):
   ```swift
   enum NavigationItem: String, CaseIterable {
       case dns, dhcp, service, logs, newFeature
   }
   ```

3. **Add the case in the switch statement**:
   ```swift
   case .newFeature:
       NewFeatureView()
   ```

### Adding a New Service

1. **Create the service** in `Services/`:
   ```swift
   @MainActor
   class NewService: ObservableObject {
       @Published var data: SomeType

       func performAction() async {
           // Implementation
       }
   }
   ```

2. **Add to the app** (`dnsmasqGUIApp.swift`):
   ```swift
   @StateObject private var newService = NewService()

   // In body:
   .environmentObject(newService)
   ```

## Testing

### Manual Testing Checklist

- [ ] App launches without errors
- [ ] Config loads from `/opt/homebrew/etc/dnsmasq.conf`
- [ ] DNS records display correctly
- [ ] Adding/editing/deleting records works
- [ ] Save writes to config file (prompts for password)
- [ ] Service start/stop/restart works
- [ ] Status updates correctly
- [ ] Logs display and auto-refresh
- [ ] Log filtering works
- [ ] Export saves to file

### Testing Without dnsmasq

For UI development, you can mock the services:

```swift
class MockConfigManager: ConfigManager {
    override func loadConfig() async {
        config = DnsmasqConfig()
        config.dnsRecords = [
            DNSRecord(recordType: .address, domain: "test.local", value: "127.0.0.1")
        ]
    }
}
```

### SwiftUI Previews

Each view includes a preview:

```swift
#Preview {
    DNSConfigView()
        .environmentObject(ConfigManager())
}
```

## Code Style

### Swift Style Guidelines

- Use Swift's standard naming conventions (camelCase for variables/functions, PascalCase for types)
- Prefer `let` over `var` when possible
- Use explicit types only when necessary for clarity
- Keep functions focused and small
- Use `async/await` for asynchronous operations

### SwiftUI Guidelines

- Extract reusable components into separate structs
- Use `@StateObject` for owned objects, `@EnvironmentObject` for shared dependencies
- Keep view bodies concise; extract complex logic into computed properties or methods
- Use semantic colors (`Color.primary`, `Color.secondary`) for theme support

### Documentation

- Add doc comments for public APIs:
  ```swift
  /// Parses a dnsmasq configuration line into a DNSRecord
  /// - Parameter line: The raw config line (e.g., "address=/domain/ip")
  /// - Returns: A DNSRecord if parsing succeeds, nil otherwise
  static func fromConfigLine(_ line: String) -> DNSRecord?
  ```

### File Organization

Within each file, organize code in this order:
1. Imports
2. Main type declaration
3. Properties
4. Initializers
5. Public methods
6. Private methods
7. Nested types
8. Extensions
9. Previews (for views)

## Submitting Changes

### Pull Request Process

1. **Fork** the repository

2. **Create a branch** for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes** following the code style guidelines

4. **Test thoroughly** using the manual testing checklist

5. **Commit with clear messages**:
   ```bash
   git commit -m "Add cname record type support"
   ```

6. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Open a Pull Request** with:
   - Clear description of changes
   - Screenshots for UI changes
   - Testing notes

### Commit Message Format

```
<type>: <short description>

<optional body with more details>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Review Process

1. Maintainers will review your PR
2. Address any requested changes
3. Once approved, your PR will be merged

## Questions?

Open an issue on GitHub or start a discussion. We're happy to help!
