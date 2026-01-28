# Taskbar Feature Design Document

## Overview

The Taskbar feature adds a Windows-style persistent taskbar to macOS, displaying all open windows at the bottom of each screen. Users can click on items to focus windows and hover to see thumbnail previews.

## Architecture

### Core Components

```
src/
├── ui/taskbar/
│   ├── TaskbarPanel.swift         # NSPanel for each screen's taskbar
│   ├── TaskbarView.swift          # Container view with blur effect
│   ├── TaskbarItemView.swift      # Individual window item (icon + title)
│   └── TaskbarPreviewPanel.swift  # Hover thumbnail preview popup
├── logic/
│   └── TaskbarManager.swift       # Central manager, multi-monitor support
└── ui/preferences-window/tabs/appearance/
    └── TaskbarSettingsSheet.swift # Settings UI
```

### Class Responsibilities

#### TaskbarManager
- Singleton managing all taskbar panels
- Creates/removes panels as monitors connect/disconnect
- Filters windows per-screen and per-space
- Adjusts maximized windows to leave room for taskbar
- Tracks adjusted windows for restoration on disable

#### TaskbarPanel
- `NSPanel` subclass with `nonactivatingPanel` style
- Uses dock window level to stay above maximized windows
- `collectionBehavior = [.canJoinAllSpaces, .stationary]`
- Positioned at bottom of each screen's `visibleFrame`

#### TaskbarView
- `NSVisualEffectView` with blur material
- Horizontal layout of `TaskbarItemView` items
- Handles scrolling when items overflow

#### TaskbarItemView
- Displays app icon and window title
- Mouse tracking for hover highlight
- Shows `TaskbarPreviewPanel` on hover (0.3s delay)
- Click to focus window

#### TaskbarPreviewPanel
- Singleton popup showing window thumbnail
- Positioned above hovered taskbar item
- Fade in/out animations
- Auto-adjusts to stay within screen bounds

## Window Filtering

Windows are filtered based on preferences:

```swift
// Per-screen: only show windows on the same screen
guard window.screenId == screenUuid

// Per-space: optionally filter by visible space
if spacesToShow == .visible {
    guard visibleSpacesForScreen.contains(window.spaceIds)
}

// Additional filters
- taskbarShowMinimizedWindows
- taskbarShowHiddenWindows
- taskbarShowFullscreenWindows
```

## Maximized Window Adjustment

Since macOS doesn't provide a public API to reserve screen space (like the Dock does), we detect and resize maximized windows:

1. **Detection**: Window fills screen's `visibleFrame` (position and size match)
2. **Adjustment**: Reduce height by `taskbarHeight`, keep top position
3. **Tracking**: Store adjusted window IDs for restoration
4. **Restoration**: On taskbar disable, restore windows to full size

```swift
// Detection logic
let isMaximizedWidth = abs(position.x - visibleFrame.minX) < tolerance
    && abs(size.width - visibleFrame.width) < tolerance
let isMaximizedHeight = abs(position.y - expectedWindowY) < tolerance
    && abs(size.height - expectedWindowHeight) < tolerance
```

## Preferences

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `taskbarEnabled` | Bool | true | Enable/disable taskbar |
| `taskbarHeight` | Int | 32 | Taskbar height in pixels |
| `taskbarItemHeight` | Int | 26 | Item height in pixels |
| `taskbarIconSize` | Int | 18 | App icon size in pixels |
| `taskbarFontSize` | Int | 11 | Title font size in points |
| `taskbarSpacesToShow` | Enum | visible | Show windows from: visible/all spaces |
| `taskbarShowMinimizedWindows` | Enum | show | Show/hide minimized windows |
| `taskbarShowHiddenWindows` | Enum | hide | Show/hide hidden windows |
| `taskbarShowFullscreenWindows` | Enum | show | Show/hide fullscreen windows |

## Event Handling

### Window Events
- `kAXWindowResizedNotification` / `kAXWindowMovedNotification`: Check and adjust if maximized
- Window creation/destruction: Update taskbar contents

### Space Events
- `NSWorkspace.activeSpaceDidChangeNotification`: Refresh `Spaces.visibleSpaces`, update taskbar

### Screen Events
- Monitor connect/disconnect: `repositionAll()` to add/remove panels

## Multi-Monitor Support

Each screen gets its own `TaskbarPanel` identified by `ScreenUuid`:

```swift
var taskbarPanels = [ScreenUuid: TaskbarPanel]()

func repositionAll() {
    // Remove panels for disconnected screens
    for uuid in existingUuids.subtracting(currentUuids) {
        taskbarPanels[uuid]?.orderOut(nil)
        taskbarPanels.removeValue(forKey: uuid)
    }

    // Add/reposition panels for current screens
    for screen in NSScreen.screens {
        if let uuid = screen.uuid() {
            // Create or reposition panel
        }
    }
}
```

## Limitations

1. **No true screen space reservation**: Cannot use private APIs like the Dock does without disabling SIP. Workaround: adjust maximized windows programmatically.

2. **Thumbnail availability**: Thumbnails may not be immediately available for newly opened windows.

3. **Fullscreen spaces**: Taskbar is hidden on fullscreen spaces (standard macOS behavior for dock-level windows).

## Future Improvements

- [ ] Window grouping by application
- [ ] Drag and drop window reordering
- [ ] Right-click context menu (close, minimize, etc.)
- [ ] Taskbar auto-hide option
- [ ] Custom taskbar position (top, left, right)
