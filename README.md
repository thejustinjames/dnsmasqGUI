# dnsmasqGUI

A native macOS GUI application for managing dnsmasq, built with SwiftUI. Provides a user-friendly interface for DNS/DHCP configuration, service control, and log viewing.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **DNS Configuration** - Manage DNS records, upstream servers, and domain overrides
- **DHCP Configuration** - Configure IP ranges, static leases, and DHCP options
- **Service Control** - Start, stop, and restart dnsmasq with two execution modes:
  - **Homebrew Services** - Managed via `brew services` (persistent, auto-start on boot)
  - **Local Process** - Run dnsmasq directly (manual control, no persistence)
- **Log Viewer** - Real-time log monitoring with filtering and export
- **Path Configuration** - Customize dnsmasq binary and config file locations

## Prerequisites

### 1. macOS Version
- macOS 13.0 (Ventura) or later

### 2. Xcode (for building from source)
- Xcode 15.0 or later
- Install from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835)

### 3. Homebrew (Optional but Recommended)
Homebrew is required for the "Homebrew Services" execution mode. If you don't have Homebrew installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 4. dnsmasq
**Option A: Install via Homebrew (Recommended)**
```bash
brew install dnsmasq
```

**Option B: Manual Installation**
If you prefer not to use Homebrew, you can compile dnsmasq from source or use another package manager. The app supports custom binary paths via Settings.

## Installation

### Option 1: Download Release (Recommended)
1. Go to the [Releases](https://github.com/yourusername/dnsmasqGUI/releases) page
2. Download the latest `dnsmasqGUI.app.zip`
3. Unzip and drag `dnsmasqGUI.app` to your Applications folder
4. Right-click and select "Open" (required for first launch of unsigned apps)

### Option 2: Build from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/dnsmasqGUI.git
   cd dnsmasqGUI
   ```

2. **Open in Xcode**
   ```bash
   open dnsmasqGUI.xcodeproj
   ```

3. **Build and Run**
   - Press `Cmd + R` to build and run
   - Or select Product → Build (`Cmd + B`) to build only

4. **Export App (Optional)**
   - Select Product → Archive
   - In the Organizer, click "Distribute App"
   - Choose "Copy App" to export the .app bundle

## Initial Setup

### 1. Configure dnsmasq
Before using the GUI, ensure dnsmasq has a configuration file:
```bash
# Create config if it doesn't exist
if [ ! -f /opt/homebrew/etc/dnsmasq.conf ]; then
    cp /opt/homebrew/opt/dnsmasq/dnsmasq.conf.example /opt/homebrew/etc/dnsmasq.conf
fi
```

### 2. Start dnsmasq Service
```bash
sudo brew services start dnsmasq
```

### 3. Configure macOS to Use dnsmasq (Optional)
To use dnsmasq as your local DNS resolver:
```bash
# Create resolver directory
sudo mkdir -p /etc/resolver

# Point .local domains to dnsmasq
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/local
```

Or set your system DNS to `127.0.0.1` in System Settings → Network → DNS.

## Usage

### DNS Configuration
1. Navigate to "DNS Configuration" in the sidebar
2. Click "Add Record" to create a new DNS entry
3. Choose the record type:
   - **Address Override**: Map a domain to a specific IP
   - **Upstream Server**: Use a specific DNS server for a domain
   - **Local Only**: Answer locally, never forward
4. Click "Save" to write changes to the config file

### DHCP Configuration
1. Navigate to "DHCP Configuration" in the sidebar
2. Use the tabs to switch between:
   - **Ranges**: Define DHCP IP address pools
   - **Static Hosts**: Assign fixed IPs to MAC addresses
   - **Options**: Configure DHCP options (gateway, DNS, etc.)
3. Click "Save" to apply changes

### Service Control
1. Navigate to "Service Control" in the sidebar
2. **Choose Execution Mode**:
   - **Homebrew Services**: Uses `brew services` to manage dnsmasq. The service starts automatically on boot and is managed by launchd. Recommended for most users.
   - **Local Process**: Runs dnsmasq directly as a process. Provides full control but won't persist after reboot.
3. View current service status (Running/Stopped/Error)
4. Use buttons to Start, Stop, or Restart the service
5. Click "Validate Config" to check for syntax errors before starting
6. Click "Settings" to configure custom paths for the dnsmasq binary and config file

### Log Viewer
1. Navigate to "Log Viewer" in the sidebar
2. Logs are displayed in real-time
3. Use the search box to filter entries
4. Toggle "Auto-scroll" to follow new entries
5. Click "Export" to save logs to a file

## Execution Modes

### Homebrew Services Mode (Default)
- Uses `brew services start/stop/restart dnsmasq`
- Service is managed by launchd
- Automatically starts on system boot
- Recommended for production use

### Local Process Mode
- Runs dnsmasq directly using the binary path
- Full control over the process lifecycle
- Does not persist after reboot
- Useful for testing or temporary DNS setups

To switch modes, go to Service Control and use the mode selector or click Settings.

## Configuration File Location

dnsmasqGUI reads and writes to (auto-detected):
```
/opt/homebrew/etc/dnsmasq.conf    # Apple Silicon Macs
/usr/local/etc/dnsmasq.conf       # Intel Macs
/etc/dnsmasq.conf                 # System-wide install
```

You can customize the path in Service Control → Settings.

## Permissions

The app requires administrator privileges to:
- Read/write the dnsmasq configuration file
- Start/stop the dnsmasq service via `brew services`

You will be prompted for your password when performing these actions.

## Troubleshooting

### "dnsmasq not found in services list"
Ensure dnsmasq is installed and registered:
```bash
brew services list | grep dnsmasq
```
If not listed, reinstall:
```bash
brew reinstall dnsmasq
```

### "Configuration file not found"
Create the configuration file:
```bash
sudo touch /opt/homebrew/etc/dnsmasq.conf
sudo chmod 644 /opt/homebrew/etc/dnsmasq.conf
```

### Service won't start
Check for port conflicts (port 53):
```bash
sudo lsof -i :53
```
Stop any conflicting services before starting dnsmasq.

### Permission denied errors
Ensure you have admin rights and that the app is allowed to run AppleScript:
1. Open System Settings → Privacy & Security → Automation
2. Enable dnsmasqGUI for "System Events"

### Logs not appearing
Check if logging is enabled in dnsmasq.conf:
```bash
echo "log-queries" | sudo tee -a /opt/homebrew/etc/dnsmasq.conf
echo "log-facility=/opt/homebrew/var/log/dnsmasq.log" | sudo tee -a /opt/homebrew/etc/dnsmasq.conf
sudo brew services restart dnsmasq
```

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Reload Configuration | `Cmd + R` |
| Start Service | `Cmd + Shift + S` |
| Stop Service | `Cmd + Shift + X` |
| Restart Service | `Cmd + Shift + R` |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html) - The underlying DNS/DHCP server
- [Homebrew](https://brew.sh/) - Package manager for macOS
