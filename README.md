# CPU Cap

**Free macOS menu bar app that limits CPU-hungry apps to efficiency cores.**

An open-source alternative to App Tamer ($15).

![CPU Cap Screenshot](screenshots/main.png)

## Download

**[Download CPU Cap v1.2.0](https://github.com/nicokosi/cpucap/releases/latest)**

Requires macOS 14.0 (Sonoma) or later. Optimized for Apple Silicon Macs.

## What It Does

Some apps hog your CPU even when you're not using them - draining battery, spinning fans, and slowing everything down. CPU Cap lets you limit background apps to efficiency cores, saving up to 70% energy.

**Before:** Chrome uses 80% CPU in the background on P-cores, laptop gets hot  
**After:** Chrome is E-limited, uses 70% less power, stays cool and quiet

## Features

- **E-limited mode** - Limit apps to E-cores to save power
- **Auto-stop mode** - Pause apps when in background, resume when focused
- **Live CPU chart** - Stacked graph showing unlimited vs limited CPU usage
- **Real-time monitoring** - See CPU usage sorted by Now & Average
- **Adjustable sampling** - Set update interval from 0.5s to 5s
- **Menu bar app** - Click the icon to see and control apps
- **Lightweight** - Uses <1% CPU itself
- **Open source** - Free forever, no tracking, no ads

## How It Works

CPU Cap uses macOS Quality of Service (QoS) to control which CPU cores apps run on:

| Mode | What it does | Best for |
|------|--------------|----------|
| **Full Speed** | Runs on all cores (P + E) | Active apps |
| **E-limited** | Limits to E-cores via QoS | Background apps you want running |
| **Auto-stop** | Pauses when in background, resumes when focused | Apps you only need when visible |

### Why E-cores?

Apple Silicon Macs have two types of CPU cores:
- **P-cores (Performance)** - Fast but power-hungry
- **E-cores (Efficiency)** - Slower but use ~70% less energy

When you E-limit an app, it keeps running smoothly but uses far less power. Your P-cores stay free for the apps you're actively using.

## The Interface

### Header
Shows your CPU model and usage breakdown:
- **Total** - Overall CPU usage
- **X P-cores** - Performance core usage  
- **X E-cores** - Efficiency core usage

### Chart
Stacked area chart showing CPU breakdown over time:
- **Green** - Unlimited apps
- **Blue** - E-limited apps
- **Orange** - Auto-stopped apps
- **White line** - Total CPU

### Process List
Apps sorted by average CPU usage. Each row shows:
- **Status dot** - Green (unlimited), Blue (E-limited), Orange (auto-stopped)
- **App name** - Click for detailed sub-process view
- **CPU bar** - Visual indicator (full bar = 50% of P-core capacity)
- **Now** - Current CPU percentage
- **Avg** - Lifetime average CPU
- **Mode** - Click to change (E = E-limited, S = Auto-stop)

### Footer
Shows count of limited apps. Click to expand and see the list.

## Installation

1. Download the DMG from [Releases](https://github.com/nicokosi/cpucap/releases)
2. Open the DMG file
3. Drag CPU Cap to your Applications folder
4. Open CPU Cap from Applications
5. Click "Open" if macOS asks about unidentified developer

## Settings

Access via the Settings button in the footer:

- **Startup** - Launch at login
- **Sampling** - Adjust update interval (0.5s - 5s)
- **Rules** - View and manage saved app modes
- **Alerts** - Configure CPU hog notifications

## FAQ

**Does it work on Apple Silicon (M1/M2/M3/M4)?**  
Yes! CPU Cap is optimized for Apple Silicon and uses E-core affinity.

**What's the difference vs percentage-based throttling?**  
Old tools freeze apps in cycles (run 20%, frozen 80%), causing stuttering. E-limiting keeps apps running smoothly on slower cores.

**Will E-limiting slow down my apps?**  
E-cores are 2-3x slower than P-cores, but for background tasks this is usually fine. The app keeps running - it's not paused.

**What about Auto-stop mode?**  
Auto-stop completely pauses the app (SIGSTOP) when it's in the background. When you click on the app, it instantly resumes.

**Why does Activity Monitor still show high CPU?**  
Activity Monitor shows CPU time, not which cores. An E-limited app may show high %, but uses less power on E-cores.

**Does it remember my settings?**  
Yes, all modes are saved and restored when apps restart.

## Building from Source

Requires Xcode 15+ and macOS 14+.

```bash
git clone https://github.com/nicokosi/cpucap.git
cd cpucap

# Development build
cd CPUCap
swift build
.build/debug/CPUCap

# Release build
./scripts/build-release.sh 1.2.0

# Create DMG installer
./scripts/create-dmg.sh 1.2.0
```

## Project Structure

```
cpucap/
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

Contributions welcome! Please open an issue first to discuss changes.

## License

MIT License - see [LICENSE](LICENSE)

---

**Like CPU Cap?** Star the repo to help others find it!
