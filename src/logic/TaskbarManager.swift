import Cocoa

class TaskbarManager {
    static var shared = TaskbarManager()
    var taskbarPanels = [ScreenUuid: TaskbarPanel]()
    var isEnabled = false
    private var badgeRefreshTimer: Timer?

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        createPanelsForAllScreens()
        updateContents()
        // adjust any already-maximized windows to leave room for taskbar
        adjustAllWindows()
        startBadgeRefreshTimer()
    }

    func disable() {
        guard isEnabled else { return }
        isEnabled = false
        badgeRefreshTimer?.invalidate()
        badgeRefreshTimer = nil
        for (_, panel) in taskbarPanels {
            panel.orderOut(nil)
        }
        taskbarPanels.removeAll()
    }

    private func createPanelsForAllScreens() {
        for screen in NSScreen.screens {
            if let uuid = screen.uuid(), taskbarPanels[uuid] == nil {
                let panel = TaskbarPanel(screenUuid: uuid)
                panel.positionAtScreenBottom(screen)
                panel.orderFront(nil)
                taskbarPanels[uuid] = panel
            }
        }
    }

    func repositionAll() {
        guard isEnabled else { return }

        let currentUuids = Set(NSScreen.screens.compactMap { $0.uuid() })
        let existingUuids = Set(taskbarPanels.keys)

        // remove panels for disconnected screens
        for uuid in existingUuids.subtracting(currentUuids) {
            taskbarPanels[uuid]?.orderOut(nil)
            taskbarPanels.removeValue(forKey: uuid)
        }

        // add panels for new screens and reposition existing
        for screen in NSScreen.screens {
            if let uuid = screen.uuid() {
                if let panel = taskbarPanels[uuid] {
                    panel.positionAtScreenBottom(screen)
                } else {
                    let panel = TaskbarPanel(screenUuid: uuid)
                    panel.positionAtScreenBottom(screen)
                    panel.orderFront(nil)
                    taskbarPanels[uuid] = panel
                }
            }
        }

        updateContents()
    }

    func updateContents() {
        guard isEnabled else { return }
        for (screenUuid, panel) in taskbarPanels {
            if hasFullscreenWindow(on: screenUuid) {
                panel.orderOut(nil)
            } else {
                panel.orderFront(nil)
                let filteredWindows = filterWindowsForTaskbar(screenUuid: screenUuid)
                panel.updateContents(filteredWindows)
            }
        }
    }

    private func hasFullscreenWindow(on screenUuid: ScreenUuid) -> Bool {
        return Windows.list.contains { window in
            !window.isWindowlessApp &&
                window.screenId == screenUuid &&
                window.isFullscreen
        }
    }

    private func filterWindowsForTaskbar(screenUuid: ScreenUuid) -> [Window] {
        let screenSpaces = Spaces.screenSpacesMap[screenUuid] ?? []
        let visibleSpacesForScreen = Spaces.visibleSpaces.filter { screenSpaces.contains($0) }

        return Windows.list.sorted {$0.creationOrder < $1.creationOrder }.filter { window in
            // basic filter: should show to user and not a windowless app
            guard !window.isWindowlessApp else { return false }

            // filter by screen
            guard window.screenId == screenUuid else { return false }

            // filter by space
            let spacesToShow = Preferences.taskbarSpacesToShow
            if spacesToShow == .visible {
                // only show windows on visible space for this screen
                guard visibleSpacesForScreen.contains(where: { visibleSpace in window.spaceIds.contains { $0 == visibleSpace } }) else { return false }
            }
            // .all shows windows from all spaces

            // filter minimized windows
            if Preferences.taskbarShowMinimizedWindows == .hide && window.isMinimized {
                return false
            }

            // filter hidden windows
            if Preferences.taskbarShowHiddenWindows == .hide && window.isHidden {
                return false
            }

            // filter fullscreen windows
            if Preferences.taskbarShowFullscreenWindows == .hide && window.isFullscreen {
                return false
            }

            return true
        }
    }

    private func startBadgeRefreshTimer() {
        badgeRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshBadges()
        }
    }

    func refreshBadges() {
        guard isEnabled, !Preferences.hideAppBadges else { return }
        BackgroundWork.accessibilityCommandsQueue.addOperation {
            guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
            let dockPid = dockApp.processIdentifier
            let axDock = AXUIElementCreateApplication(dockPid)
            var childrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axDock, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                  let children = childrenRef as? [AXUIElement] else { return }
            // find the list element in dock
            var listElement: AXUIElement?
            for child in children {
                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef) == .success,
                   let role = roleRef as? String, role == kAXListRole {
                    listElement = child
                    break
                }
            }
            guard let list = listElement else { return }
            var listChildrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &listChildrenRef) == .success,
                  let listChildren = listChildrenRef as? [AXUIElement] else { return }
            var results = [(URL?, String?)]()
            for item in listChildren {
                var subroleRef: CFTypeRef?
                var runningRef: CFTypeRef?
                var urlRef: CFTypeRef?
                var labelRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, kAXSubroleAttribute as CFString, &subroleRef)
                AXUIElementCopyAttributeValue(item, "AXIsApplicationRunning" as CFString, &runningRef)
                guard let subrole = subroleRef as? String, subrole == "AXApplicationDockItem",
                      let running = runningRef as? Bool, running else { continue }
                AXUIElementCopyAttributeValue(item, kAXURLAttribute as CFString, &urlRef)
                AXUIElementCopyAttributeValue(item, kAXStatusLabelAttribute as CFString, &labelRef)
                let url = urlRef as? URL ?? (urlRef as? NSURL)?.absoluteURL
                let label = labelRef as? String
                results.append((url, label))
            }
            guard !results.isEmpty else { return }
            DispatchQueue.main.async {
                for app in Applications.list {
                    if app.runningApplication.activationPolicy == .regular,
                       let matchingItem = (results.first { $0.0 == app.bundleURL }) {
                        app.dockLabel = matchingItem.1
                    } else {
                        app.dockLabel = nil
                    }
                }
                TaskbarManager.shared.updateContents()
            }
        }
    }

    func updateAppearance() {
        for (_, panel) in taskbarPanels {
            panel.updateAppearance()
        }
    }

    /// Adjusts all windows that overlap with the taskbar
    /// Called when taskbar is enabled or taskbar height changes
    func adjustAllWindows() {
        guard isEnabled else { return }
        for window in Windows.list {
            adjustWindowIfNeeded(window)
        }
    }

    /// Shrinks a window if its bottom edge overlaps the taskbar area
    /// Handles maximized windows, tiled windows (e.g. left/right half in macOS Sequoia), etc.
    /// Called when a window is resized or moved
    func adjustWindowIfNeeded(_ window: Window) {
        guard isEnabled else { return }
        guard !window.isWindowlessApp else { return }
        guard !window.isFullscreen else { return } // don't adjust actual fullscreen windows
        guard let axUiElement = window.axUiElement else { return }
        guard let position = window.position, let size = window.size else { return }
        guard let screenId = window.screenId else { return }

        // find the screen for this window
        guard let screen = NSScreen.screens.first(where: { $0.uuid() == screenId }) else { return }

        let visibleFrame = screen.visibleFrame
        let taskbarHeight = Preferences.taskbarHeight

        // convert screen coordinates (origin at bottom-left) to window coordinates (origin at top-left)
        let screenTopLeftY = NSMaxY(NSScreen.screens[0].frame) - NSMaxY(visibleFrame)
        let taskbarTop = screenTopLeftY + visibleFrame.height - taskbarHeight
        let windowBottom = position.y + size.height

        let tolerance: CGFloat = 2

        // check if the window's bottom edge extends into the taskbar area
        let overlapsTaskbar = windowBottom > taskbarTop + tolerance
        // check if already adjusted (bottom edge is at taskbar top)
        let isAlreadyAdjusted = abs(windowBottom - taskbarTop) <= tolerance

        if overlapsTaskbar && !isAlreadyAdjusted {
            // shrink window so its bottom edge sits at the top of the taskbar
            let newHeight = taskbarTop - position.y

            if newHeight > 0 && abs(size.height - newHeight) > tolerance {
                BackgroundWork.accessibilityCommandsQueue.addOperation {
                    var newSize = CGSize(width: size.width, height: newHeight)
                    if let sizeValue = AXValueCreate(.cgSize, &newSize) {
                        try? axUiElement.setAttribute(kAXSizeAttribute, sizeValue)
                    }

                    // re-set position in case resizing shifted it
                    var newPosition = CGPoint(x: position.x, y: position.y)
                    if let posValue = AXValueCreate(.cgPoint, &newPosition) {
                        try? axUiElement.setAttribute(kAXPositionAttribute, posValue)
                    }
                }
            }
        }
    }
}
