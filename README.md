<p align="center">
  <img src="https://img.shields.io/badge/Handed-DNS_Manager-ff6b35?style=for-the-badge&labelColor=dc2626&color=ff6b35" alt="Handed" />
</p>

<h1 align="center">
  <br>
  🤚 Handed
  <br>
</h1>

<h4 align="center">A native macOS GUI for managing dnsmasq and DNS resolvers</h4>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-007AFF?style=flat-square&logo=apple&logoColor=white" alt="macOS 13.0+" />
  <img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/SwiftUI-Native-5c5ce6?style=flat-square&logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Version-2.0.0-green?style=flat-square" alt="v2.0.0" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License" />
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-build">Build</a>
</p>

---

## Why Handed?

Managing local DNS shouldn't require memorizing config syntax and terminal commands. **Handed** gives you complete control over dnsmasq and macOS resolver files with a beautiful native interface—plus a menu bar app for quick access.

```
No more:                              With Handed:
vim /opt/homebrew/etc/dnsmasq.conf    Click "Add Record"
sudo mkdir -p /etc/resolver           Click "Create Resolver"
sudo tee /etc/resolver/local          One-click TLD presets
sudo dscacheutil -flushcache          Menu bar → Flush DNS
```

## ✨ Features

### Core Features
| Feature | Description |
|---------|-------------|
| **DNS Management** | Add, edit, and test DNS records with live preview |
| **DHCP Configuration** | Set up IP ranges, static leases, and network options |
| **Resolver Files** | Create and manage `/etc/resolver/*` files |
| **Service Control** | Run via Homebrew Services or as a local process |
| **Live Log Viewer** | Watch DNS queries in real-time with filtering |

### New in v2.0.0
| Feature | Description |
|---------|-------------|
| **🤚 Menu Bar App** | Quick access to start/stop, flush DNS, and status |
| **💾 Backup & Restore** | Save and restore all configurations |
| **📥 Import/Export** | Import from `/etc/hosts`, export configs |
| **⚡ Quick TLD Presets** | One-click setup for `.local`, `.test`, `.dev`, etc. |
| **🔧 Troubleshooting Tools** | DNS testing, cache flush, port checker |

## 🚀 Quick Start

**1. Install dnsmasq:**
```bash
brew install dnsmasq
```

**2. Download Handed:**
- Grab from [Releases](https://github.com/thejustinjames/handed/releases)
- Or build from source (see below)

**3. Set up local DNS in 60 seconds:**
1. Open Handed
2. Go to **Backup & Import** → Click `.local` preset
3. Go to **DNS Configuration** → Add your records
4. Go to **Service Control** → Start dnsmasq
5. Done! Your `*.local` domains now resolve

## 📦 Installation

### Option A: Download Release
1. Download from [Releases](https://github.com/thejustinjames/handed/releases)
2. Drag `Handed.app` to Applications
3. Right-click → Open (first launch only)

### Option B: Build from Source
```bash
git clone https://github.com/thejustinjames/handed.git
cd handed
make release      # Build release + ZIP
make dmg          # Create installer DMG
```

## 🎮 Usage

### Menu Bar Quick Access
The menu bar icon shows dnsmasq status at a glance:
- 🟢 **Green hand** = Running
- ⚪ **Gray hand** = Stopped
- 🔴 **Red hand** = Error

Click for quick actions: Start, Stop, Restart, Flush DNS

### DNS Record Types

| Type | What It Does | Example |
|------|--------------|---------|
| **Address Override** | Point domain to IP | `myapp.local` → `127.0.0.1` |
| **Upstream Server** | Route to specific DNS | `*.corp` → `10.0.0.1` |
| **Local Only** | Never forward externally | `internal.dev` |

### Resolver Files

Resolver files tell macOS to use specific DNS servers for certain TLDs:

```
/etc/resolver/local     → Routes *.local to 127.0.0.1
/etc/resolver/test      → Routes *.test to 127.0.0.1
/etc/resolver/dev       → Routes *.dev to 127.0.0.1
```

Create them instantly with the **Quick TLD Presets** in Backup & Import.

### Keyboard Shortcuts

| Action | Keys |
|--------|------|
| Reload Config | `⌘R` |
| Start Service | `⇧⌘S` |
| Stop Service | `⇧⌘X` |
| Restart Service | `⇧⌘R` |
| Help | `⌘?` |

## 🔧 Build

```bash
# Prerequisites
brew install dnsmasq
xcode-select --install

# Clone & Build
git clone https://github.com/thejustinjames/handed.git
cd handed

make build      # Build debug version
make release    # Build release + create ZIP
make dmg        # Create DMG installer
make clean      # Clean build artifacts
make run        # Build and launch
```

Build output:
```
dist/
├── Handed.app
├── Handed-v2.0.0-macOS.zip
└── Handed-v2.0.0-macOS.dmg
```

## 🩺 Troubleshooting

### Built-in Tools
Handed includes a full **Troubleshooting** section with:
- Flush DNS Cache
- Test DNS resolution (dscacheutil, dig, nslookup)
- Check port 53 usage
- View dnsmasq config
- List resolver files

### Common Issues

<details>
<summary><b>DNS not resolving?</b></summary>

1. Open Handed → **Troubleshooting**
2. Click **Flush DNS Cache**
3. Verify dnsmasq is running in **Service Control**
4. Check resolver file exists in **Resolver Files**
5. Test with: `dig @127.0.0.1 yourdomain.local`
</details>

<details>
<summary><b>Service won't start?</b></summary>

Check if something else is using port 53:
```bash
sudo lsof -i :53
```
Or use **Troubleshooting** → **Check Port 53**
</details>

<details>
<summary><b>Permission errors?</b></summary>

1. Open **System Settings** → **Privacy & Security** → **Automation**
2. Enable Handed for "System Events"
</details>

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ☕ by <a href="https://github.com/thejustinjames">Justin James</a>
  <br>
  <sub>2026</sub>
</p>
