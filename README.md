# CPU Cap

**Free macOS menu bar app that manages CPU usage using Apple Silicon efficiency cores.**

An open-source alternative to App Tamer ($15).

![CPU Cap Screenshot](screenshots/main.png)

## Download

**[Download CPU Cap](https://github.com/nostitos/macos-cpucap/releases/latest)**

Requires macOS 14.0 (Sonoma) or later. Optimized for Apple Silicon Macs.

## What It Does

Some apps hog your CPU even when you're not using them - draining battery, making fans spin, and slowing everything down. CPU Cap lets you push background apps to efficiency cores, saving up to 70% energy.

**Before:** Chrome uses 80% CPU in the background on P-cores, your laptop gets hot  
**After:** Chrome runs on E-cores, uses 70% less power, stays cool and quiet

## Features

- **Efficiency Mode** - Run background apps on E-cores to save power
- **Auto-Stop Mode** - Pause apps when in background, resume when focused
- **See CPU usage** - Sorted by which apps use the most (Now & Average)
- **Runs in menu bar** - Click the icon to see and control apps
- **Lightweight** - Uses <1% CPU itself when menu is closed
- **Open source** - Free forever, no tracking, no ads

## How It Works

CPU Cap uses macOS Quality of Service (QoS) to control which CPU cores apps run on:

| Mode | What it does | Best for |
|------|--------------|----------|
| **Full Speed** | Runs on all cores (P + E) | Active apps |
| **Efficiency** | Hints macOS to prefer E-cores | Background apps you want running |
| **Auto-Stop** | Pauses when in background, resumes when focused | Apps you only need when visible |

### Why E-cores?

Apple Silicon Macs have two types of CPU cores:
- **P-cores (Performance)** - Fast but power-hungry
- **E-cores (Efficiency)** - Slower but use ~70% less energy

When you set an app to Efficiency mode, it keeps running smoothly but uses far less power. Your P-cores stay free for the apps you're actively using.

## Installation

1. Download the DMG from [Releases](https://github.com/nostitos/macos-cpucap/releases)
2. Open the DMG file
3. Drag CPU Cap to your Applications folder
4. Open CPU Cap from Applications
5. Click "Open" if macOS asks about unidentified developer

## How to Use

### 1. Open the Menu
Click the CPU Cap icon in your menu bar (shows current total CPU %).

### 2. Find the App
Apps are sorted by average CPU usage. Use the search bar to filter.

### 3. Set a Mode
Click the dropdown next to any app and choose:
- **Full Speed** - No throttling
- **Efficiency** - Run on E-cores (shows "E" indicator)
- **Auto-Stop** - Pause in background (shows "-" indicator)

### 4. View Details
Click on any app name to see detailed info including sub-processes:

![Process Details](screenshots/subdetails.png)

### 5. Settings
Configure startup behavior and manage saved rules:

![Settings](screenshots/settings.png)

## FAQ

**Does it work on Apple Silicon (M1/M2/M3/M4)?**  
Yes! CPU Cap is optimized for Apple Silicon and uses the E-core affinity feature. It also works on Intel Macs using the older SIGSTOP method.

**What's the difference vs the old percentage caps?**  
The old method (used by App Tamer and others) freezes apps in cycles - e.g., run 20% of the time, frozen 80%. This can cause stuttering. Efficiency mode keeps apps running smoothly, just on slower cores.

**Will Efficiency mode slow down my apps?**  
E-cores are about 2-3x slower than P-cores, but for background tasks this is usually fine. The app keeps running - it's not paused.

**What about Auto-Stop mode?**  
Auto-Stop completely pauses the app (SIGSTOP) when it's in the background. When you click on the app, it instantly resumes. Good for apps you only need when visible.

**Why does Activity Monitor still show high CPU?**  
Activity Monitor shows total CPU time, not which cores are used. An app in Efficiency mode may still show high CPU %, but it's using less power because it's on E-cores.

**Can I cap system processes?**  
Some protected system processes cannot be throttled. CPU Cap only shows apps you can actually control.

**Does it start at login?**  
Yes, you can enable this in Settings. CPU Cap remembers your modes between sessions.

**Why do I see "unidentified developer" warning?**  
The app is ad-hoc signed (not notarized with Apple). You can safely click "Open" or right-click and choose Open.

## Building from Source

Requires Xcode 15+ and macOS 14+.

```bash
git clone https://github.com/nostitos/macos-cpucap.git
cd macos-cpucap

# Development build
cd CPUCap
swift build
.build/debug/CPUCap

# Release build (universal binary)
./scripts/build-release.sh 1.0.1

# Create DMG installer
./scripts/create-dmg.sh 1.0.1
```

## Project Structure

```
macos-cpucap/
├── CPUCap/                 # Swift package
│   ├── Package.swift
│   └── CPUCap/
│       ├── CPUCapApp.swift     # App entry point
│       ├── Core/               # Process monitoring & limiting
│       ├── UI/                 # SwiftUI views
│       └── Resources/          # Icons
├── scripts/                # Build scripts
├── dmg-resources/          # DMG background images
└── screenshots/            # Documentation images
```

## Contributing

Contributions welcome! Please open an issue first to discuss what you'd like to change.

## License

MIT License - see [LICENSE](LICENSE)

## Credits

Made with frustration at Chrome's CPU usage.

---

**Like CPU Cap?** Star the repo to help others find it!
