# Mac-Tools

Collection of lightweight, native tools and menu bar utilities built for macOS.

---

## ⚡ NetSpeed Monitor

A lightweight, real-time network speed and data usage monitor in your macOS menu bar with an interactive speedometer gauge.

```text
 🧭 0.0 MB/s
 ┌──────────────────────────────────────────────┐
 │ Download: 0.0 MB/s  |  Upload: 0.0 MB/s      │
 │ Session:  ↓ 67.4 MB    ↑ 118.8 MB            │
 ├──────────────────────────────────────────────┤
 │ 7 OCT     ↓ 1.0 GB     ↑ 5.7 GB              │
 │ 8 OCT     ↓ 530 KB     ↑ 245 KB              │
 │ 9 OCT     ↓ 67.3 MB    ↑ 118.8 MB            │
 ├──────────────────────────────────────────────┤
 │ Last 7 days    ↓ 1.1 GB   ↑ 5.8 GB           │
 │ Last 30 days   ↓ 1.1 GB   ↑ 5.8 GB           │
 ├──────────────────────────────────────────────┤
 │ Quit                                      ⌘Q │
 └──────────────────────────────────────────────┘
```

### ✨ Features
- **Real-Time Speedometer Icon**: Dynamic speedometer dial gauge on your macOS menu bar that moves with active network activity.
- **Instantaneous Speed**: 200ms high-frequency sampling for zero-lag download speed readouts.
- **Detailed Dropdown Menu**:
  - Live download and upload speed.
  - Current session totals (`↓` Download / `↑` Upload).
  - 7-day daily data history tracking.
  - 7-day and 30-day total consumption summaries.
- **Native & Lightweight**: Pure Swift and AppKit. No Electron, no Node.js, zero third-party dependencies. Minimal RAM (~15 MB) and negligible CPU usage.
- **Login Auto-Start**: Automatically registered as a macOS LaunchAgent to start smoothly on login.

---

### 🚀 Quick Install (Fastest)

Open **Terminal** and run:

```bash
curl -fsSL https://raw.githubusercontent.com/sohanahamed14/Mac-Tools/main/install.sh | bash
```

> **Note**: Requires Xcode Command Line Tools (`swiftc`). If not already installed, macOS will prompt you or you can run `xcode-select --install`.

---

### 🖱️ Manual Install (Finder / Git)

1. Clone or download this repository:
   ```bash
   git clone https://github.com/sohanahamed14/Mac-Tools.git
   cd Mac-Tools
   ```
2. Double-click **`Install.command`** in Finder (or run `./Install.command` in Terminal).

---

### 🗑️ Uninstallation

Run either:

```bash
curl -fsSL https://raw.githubusercontent.com/sohanahamed14/Mac-Tools/main/uninstall.sh | bash
```

Or double-click **`Uninstall.command`**.

---

### 📄 License
MIT License. Free to use and modify.
