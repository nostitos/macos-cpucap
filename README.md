# CPU Cap

**Free macOS menu bar app that limits how much CPU any app can use.**

An open-source alternative to App Tamer ($15).

![CPU Cap Screenshot](screenshots/main.png)

## Download

**[Download CPU Cap v1.0.0](https://github.com/nostitos/macos-cpucap/releases/latest)**

Requires macOS 14.0 (Sonoma) or later. Works on both Apple Silicon and Intel Macs.

## What It Does

Some apps hog your CPU even when you're not using them - draining battery, making fans spin, and slowing everything down. CPU Cap lets you set a limit on any app's CPU usage.

**Before:** Chrome uses 80% CPU in the background, your laptop gets hot  
**After:** Chrome is capped at 20%, runs cool and quiet

## Features

- **Limit any app** - Set a CPU cap from 5% to 95%
- **See CPU usage** - Sorted by which apps use the most
- **Runs in menu bar** - Click the icon to see and control apps
- **Lightweight** - Uses <1% CPU itself when menu is closed
- **Open source** - Free forever, no tracking, no ads

## Installation

1. Download the DMG from [Releases](https://github.com/nostitos/macos-cpucap/releases)
2. Open the DMG file
3. Drag CPU Cap to your Applications folder
4. Open CPU Cap from Applications
5. Click "Open" if macOS asks about unidentified developer

![Installation](screenshots/install.png)

## How to Use

### 1. Open the Menu
Click the CPU Cap icon in your menu bar (shows current total CPU %).

![Menu Bar](screenshots/menubar.png)

### 2. Find the App
Apps are sorted by average CPU usage. Use the search bar to filter.

![Process List](screenshots/list.png)

### 3. Set a Cap
Click the dropdown next to any app and choose a limit (e.g., 20%).

![Setting a Cap](screenshots/cap.png)

The app will now be throttled. You'll see it marked as "limited" in the list.

### 4. Remove a Cap
Click the dropdown and select "—" to remove the limit.

## How It Works

CPU Cap uses macOS signals (SIGSTOP/SIGCONT) to pause and resume apps in quick cycles. An app capped at 20% runs for a short time, then pauses, then runs again - averaging out to 20% CPU usage.

This is the same technique used by Apple's own App Nap feature, and commercial tools like App Tamer.

**Is it safe?**  
Yes. Apps resume normally when you remove the cap or quit CPU Cap. No data is lost.

**Will it break apps?**  
Most apps work fine. Some real-time apps (video calls, games) may stutter if capped too low.

## FAQ

**Does it work on Apple Silicon (M1/M2/M3)?**  
Yes, CPU Cap is a universal app that runs natively on both Intel and Apple Silicon.

**Why does Activity Monitor still show high CPU?**  
Activity Monitor averages CPU over time. A capped app runs at full speed in bursts, then pauses. The average settles near your cap after a few seconds.

**Can I cap system processes?**  
Some protected system processes (like WindowServer) cannot be throttled. CPU Cap will only show apps you can actually limit.

**Does it start at login?**  
Yes, you can enable this in Settings. CPU Cap remembers your caps between sessions.

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
./scripts/build-release.sh 1.0.0

# Create DMG installer
./scripts/create-dmg.sh 1.0.0
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
