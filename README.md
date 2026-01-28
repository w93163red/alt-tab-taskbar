<div align = center>

# AltTab

[![Screenshot](docs/public/demo/frontpage.jpg)](docs/public/demo/frontpage.jpg)

**AltTab** brings the power of Windows alt-tab to macOS

[Official website](https://alt-tab-macos.netlify.app/)<br/><sub>14K stars</sub> | [Download](https://github.com/lwouis/alt-tab-macos/releases/download/v8.3.3/AltTab-8.3.3.zip)<br/><sub>6.6M downloads</sub>
-|-

<div align="right">
  <p>Project supported by</p>
  <a href="https://jb.gg/OpenSource">
    <img src="docs/public/demo/jetbrains.svg" alt="Jetbrains" width="149" height="32">
  </a>
</div>

</div>

## Features

### Windows-style Taskbar (New!)

This fork adds a **persistent Windows-style taskbar** at the bottom of the screen:

- Shows all open windows with app icons and titles
- Click to focus any window instantly
- Hover to preview window thumbnails
- Per-screen taskbar for multi-monitor setups
- Filter by current Space or show all windows
- Automatically adjusts maximized windows to leave room for the taskbar
- Fully customizable: height, icon size, font size, and more

Configure in **Preferences → Appearance → Taskbar**.

See [docs/taskbar.md](docs/taskbar.md) for technical design details.

## Building from Source

### Prerequisites

- macOS 10.13+
- Xcode 12+
- [CocoaPods](https://cocoapods.org/)

### Build

```bash
# Install dependencies
pod install

# Build Debug version
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug -configuration Debug build

# Build Release version
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Release -configuration Release build
```

### Quick build check

```bash
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug -configuration Debug build 2>&1 | grep -E "(error:|BUILD)"
```

### Run

```bash
# Open the built app (Debug)
open ~/Library/Developer/Xcode/DerivedData/alt-tab-macos-*/Build/Products/Debug/AltTab.app

# Or use Xcode to build and run
open alt-tab-macos.xcworkspace
# Then press Cmd+R in Xcode
```
