<p align="center">
  <img src="https://img.shields.io/badge/JJ-dnsmasqGUI-blueviolet?style=for-the-badge&labelColor=5c5ce6&color=9966ff" alt="JJ dnsmasqGUI" />
</p>

<h1 align="center">
  <br>
  <img width="120" height="120" src="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTIwIiBoZWlnaHQ9IjEyMCIgdmlld0JveD0iMCAwIDEyMCAxMjAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGRlZnM+PGxpbmVhckdyYWRpZW50IGlkPSJncmFkIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj48c3RvcCBvZmZzZXQ9IjAlIiBzdG9wLWNvbG9yPSIjMDA3QUZGIi8+PHN0b3Agb2Zmc2V0PSIxMDAlIiBzdG9wLWNvbG9yPSIjQUY1MkRFIi8+PC9saW5lYXJHcmFkaWVudD48L2RlZnM+PHJlY3Qgd2lkdGg9IjEyMCIgaGVpZ2h0PSIxMjAiIHJ4PSIyNCIgZmlsbD0idXJsKCNncmFkKSIvPjx0ZXh0IHg9IjYwIiB5PSI3NSIgZm9udC1mYW1pbHk9Ii1hcHBsZS1zeXN0ZW0sIEJsaW5rTWFjU3lzdGVtRm9udCwgJ1NlZ29lIFVJJywgUm9ib3RvLCBIZWx2ZXRpY2EsIEFyaWFsLCBzYW5zLXNlcmlmIiBmb250LXNpemU9IjU2IiBmb250LXdlaWdodD0iYm9sZCIgZmlsbD0id2hpdGUiIHRleHQtYW5jaG9yPSJtaWRkbGUiPkpKPC90ZXh0Pjwvc3ZnPg==" alt="JJ Logo">
  <br>
  dnsmasqGUI
  <br>
</h1>

<h4 align="center">A beautiful native macOS app for taming your local DNS/DHCP dragon</h4>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-007AFF?style=flat-square&logo=apple&logoColor=white" alt="macOS 13.0+" />
  <img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.9+" />
  <img src="https://img.shields.io/badge/SwiftUI-Native-5c5ce6?style=flat-square&logo=swift&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License" />
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-build">Build</a> •
  <a href="#-contributing">Contributing</a>
</p>

---

## Why dnsmasqGUI?

Ever wished managing your local DNS server didn't require memorizing arcane config syntax and terminal incantations? **dnsmasqGUI** brings the power of dnsmasq to your fingertips with a clean, native macOS interface.

```
No more:                          With dnsmasqGUI:
vim /opt/homebrew/etc/dnsmasq.conf    Click "Add Record"
address=/myapp.local/127.0.0.1   ->   Type domain, pick IP
sudo brew services restart dnsmasq    Click "Save"
```

## ✨ Features

| Feature | Description |
|---------|-------------|
| **DNS Management** | Add, edit, and test DNS records with a beautiful UI |
| **DHCP Configuration** | Set up IP ranges, static leases, and network options |
| **Dual-Mode Service Control** | Run via Homebrew Services OR as a local process |
| **Live Log Viewer** | Watch DNS queries in real-time with filtering |
| **DNS Testing** | Verify your records work before going live |
| **Path Flexibility** | Works with custom dnsmasq installations |

## 🚀 Quick Start

**1. Have Homebrew? Get dnsmasq:**
```bash
brew install dnsmasq
```

**2. Grab the app:**
- Download from [Releases](https://github.com/thejustinjames/dnsmasqGUI/releases)
- Or build it yourself (see below)

**3. Launch and go!**
- Add your first DNS record in seconds
- Hit "Test" to verify it works
- Click "Save" and you're done

## 📦 Installation

### Option A: Download Release
1. Head to [Releases](https://github.com/thejustinjames/dnsmasqGUI/releases)
2. Download `dnsmasqGUI-v1.0.0-macOS.zip` or `.dmg`
3. Drag to Applications
4. Right-click → Open (first launch only)

### Option B: Build from Source
```bash
git clone https://github.com/thejustinjames/dnsmasqGUI.git
cd dnsmasqGUI
make build        # Debug build
make release      # Release build + ZIP
make dmg          # Create installer DMG
```

## 🎮 Usage

### DNS Records Made Easy

| Type | What It Does | Example |
|------|--------------|---------|
| **Address Override** | Point a domain to an IP | `myapp.local` → `127.0.0.1` |
| **Upstream Server** | Use specific DNS for a domain | `*.corp` → `10.0.0.1` |
| **Local Only** | Never forward, answer locally | `internal.dev` |

### Service Control

Choose your style:

- **Homebrew Mode** - Set it and forget it. Auto-starts on boot.
- **Local Mode** - Full manual control. Perfect for testing.

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
git clone https://github.com/thejustinjames/dnsmasqGUI.git
cd dnsmasqGUI

make build      # Build debug version
make release    # Build release + create ZIP
make dmg        # Create DMG installer
make clean      # Clean build artifacts
make run        # Build and launch
```

Build artifacts land in `./dist/`:
```
dist/
├── dnsmasqGUI.app                    # The app
├── dnsmasqGUI-v1.0.0-macOS.zip       # Distributable archive
└── dnsmasqGUI-v1.0.0-macOS.dmg       # Installer image
```

## 🩺 Troubleshooting

<details>
<summary><b>Service won't start?</b></summary>

Check if something else is hogging port 53:
```bash
sudo lsof -i :53
```
Kill the imposter, then try again.
</details>

<details>
<summary><b>No logs showing?</b></summary>

Enable logging in your config:
```bash
echo "log-queries" | sudo tee -a /opt/homebrew/etc/dnsmasq.conf
echo "log-facility=/opt/homebrew/var/log/dnsmasq.log" | sudo tee -a /opt/homebrew/etc/dnsmasq.conf
sudo brew services restart dnsmasq
```
</details>

<details>
<summary><b>Permission errors?</b></summary>

1. Open **System Settings** → **Privacy & Security** → **Automation**
2. Enable dnsmasqGUI for "System Events"
</details>

## 🤝 Contributing

Found a bug? Have an idea? PRs and issues welcome!

1. Fork it
2. Branch it (`git checkout -b feature/cool-stuff`)
3. Commit it (`git commit -m 'Add cool stuff'`)
4. Push it (`git push origin feature/cool-stuff`)
5. PR it

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full scoop.

## 📄 License

MIT License - do what you want, just keep the copyright notice.

See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ☕ by <a href="https://github.com/thejustinjames">Justin James</a>
  <br>
  <sub>JJ • 2026</sub>
</p>
