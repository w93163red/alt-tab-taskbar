# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Alt-Tab is a macOS application that brings Windows-style Alt-Tab window switching to macOS. It's a system-wide utility that requires Accessibility permissions and uses macOS private APIs for functionality that Apple doesn't expose publicly (e.g., Spaces management, window ordering across spaces).

**Key constraints:**
- Minimum deployment target: macOS 10.12 (Sierra)
- Swift version: 5.8
- Cannot use Mac App Store (due to private API usage)
- No public APIs exist for many core features (Spaces, cross-space window focus)

## Build Commands

```bash
# First-time setup: generate local self-signed certificate
scripts/codesign/setup_local.sh

# Build (Debug)
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Debug

# Build (Release)
xcodebuild -workspace alt-tab-macos.xcworkspace -scheme Release -derivedDataPath DerivedData

# Run tests
xcodebuild test -workspace alt-tab-macos.xcworkspace -scheme Test -configuration Release

# Format code
npm run format

# Check formatting (lint)
npm run format:check
```

Open `alt-tab-macos.xcworkspace` (not `.xcodeproj`) in Xcode to include CocoaPods dependencies.

## Code Formatting

SwiftFormat is configured in `.swiftformat`:
- Swift 5.8
- Max line width: 110 characters
- Husky pre-commit hooks run `npm run format:check` on staged `.swift` files
- Conventional commits enforced via commitlint

## Architecture

### Directory Structure

| Path | Purpose |
|------|---------|
| `src/api-wrappers/` | Wrappers for C/ObjC APIs and private APIs |
| `src/logic/` | Business logic, models, state management |
| `src/ui/` | UI code (NSView subclasses, windows, panels) |
| `config/` | Xcode build settings (`.xcconfig` files) |
| `scripts/` | CI/CD and local development scripts |

### Threading Model

The app uses a specific threading architecture to handle system events that require RunLoops:

**Dedicated threads with RunLoops** (for APIs requiring `CFRunLoop`):
- `accessibilityEventsThread`: Window/app accessibility notifications
- `keyboardAndMouseAndTrackpadEventsThread`: Input device events via `CGEvent.tapCreate`
- `missionControlThread`: Mission Control state (protected by `NSLock`)
- `cliEventsThread`: CLI commands via `CFMessagePort`

**Operation queues** (concurrent work):
- `screenshotsQueue` (8 threads): Window thumbnail captures
- `accessibilityCommandsQueue` (4 threads): Focus/close/minimize operations
- `axCallsFirstAttemptQueue` / `axCallsRetriesQueue` (8 threads each): AX API calls with retry logic

Total thread count is capped at ~45 to stay under macOS's soft limit of 64 threads per process.

### Key Classes

- **`App`** (`src/logic/App.swift`): Main application controller, handles UI show/hide
- **`Windows`** (`src/logic/Windows.swift`): Static manager for window list and selection
- **`Applications`** (`src/logic/Applications.swift`): Tracks running applications
- **`Preferences`** (`src/logic/Preferences.swift`): User preferences (90+ settings)
- **`ThumbnailsPanel`** (`src/ui/main-window/ThumbnailsPanel.swift`): Main UI showing window thumbnails

### Private APIs

Located in `src/api-wrappers/private-apis/`. These are undocumented Apple APIs necessary for:
- Querying number of Spaces
- Focusing windows on other Spaces
- Getting window ordering information

See `src/api-wrappers/private-apis/README.md` for documentation links.

### Entry Point

`src/main.swift` handles:
1. CLI command detection (for IPC with running instance)
2. Signal handlers (SIGTERM, SIGTRAP) for graceful shutdown
3. NSException handler for crash recovery
4. Emergency exit re-enables native Command+Tab if app crashes

## Dependencies (CocoaPods)

Custom forks are maintained for some dependencies:
- **Sparkle**: Auto-update framework
- **ShortcutRecorder**: Keyboard shortcut recording
- **LetsMove**: Auto-move to Applications folder
- **AppCenter/Crashes**: Crash reporting
- **SwiftyBeaver**: Logging

## Testing

Tests are in `unit-tests/` using XCTest. The app is deeply integrated with macOS, so end-to-end testing is manual. Key test areas:
- `CustomRecorderControlTests.swift`: Keyboard shortcut validation
- `AXUIElementTests.swift`: Accessibility API wrapper tests

See `docs/Contributing.md` for the complete list of 100+ manual QA scenarios covering Spaces, shortcuts, drag-and-drop, localization, and system preferences interactions.

## Important Patterns

- UI is built programmatically (minimal InterfaceBuilder usage - only 1 XIB for menu bar)
- State is managed via static singletons (`Windows.list`, `Applications.list`)
- Accessibility API calls can block indefinitely - always use the dedicated queues with timeouts
- Screenshots are captured asynchronously; the app waits for active captures before terminating

## Before Making Changes

**Always study existing code first.** Before modifying or adding code:
1. Search for similar functionality already in the codebase - reuse existing patterns
2. Understand how related code handles the same problem (threading, error handling, state updates)
3. Check if there's an existing utility, extension, or helper that solves the problem
4. Ensure the solution fits the architecture rather than adding workarounds or patches

The goal is optimal integration, not quick fixes. A change that follows existing patterns is better than a clever but inconsistent solution.

## Code Style

The codebase follows these conventions:

**Structure:**
- Classes with static members for singletons (e.g., `Windows.list`, `Preferences.holdShortcut`)
- Extensions to organize related functionality within a file
- Computed properties preferred over getter methods for simple accessors

**Naming:**
- camelCase for all identifiers
- Descriptive method names that read like sentences: `refreshIfWindowShouldBeShownToTheUser()`
- Short parameter names (`$0`, `$1`) in compact closures
- Underscore suffix for shadowed properties: `window_` when `window` is taken

**Control Flow:**
- Heavy use of `guard` for early returns and unwrapping
- `try?` for optional error handling when failure is acceptable
- Multi-condition `if` statements with conditions on separate lines, operators at line end

**Async Patterns:**
- `DispatchQueue.main.async` for UI updates from background threads
- `DispatchQueue.main.asyncAfter(deadline:)` for delayed operations
- Closures passed to `Logger.debug/info` for lazy string evaluation

**Comments:**
- Explain "why" not "what"
- Reference GitHub issue numbers for workarounds: `// see: https://github.com/lwouis/alt-tab-macos/issues/1540`
- `TODO:` comments for known improvements

**Formatting (enforced by SwiftFormat):**
- 110 character max line width
- No wrapping for short conditional bodies
- Ternary operators break before operators
