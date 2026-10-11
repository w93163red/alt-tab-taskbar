import Cocoa

class TaskbarManager {
    static var shared = TaskbarManager()
    var taskbarPanels = [ScreenUuid: TaskbarPanel]()
    var isEnabled = false

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        repositionAll()
        adjustAllWindows()
    }

    func disable() {
        guard isEnabled else { return }
        isEnabled = false
        for (_, panel) in taskbarPanels {
            panel.orderOut(nil)
        }
        taskbarPanels.removeAll()
    }

    func repositionAll() {
        guard isEnabled else { return }

        let currentUuids = Set(NSScreen.screens.compactMap { $0.uuid() })
        let existingUuids = Set(taskbarPanels.keys)

        for uuid in existingUuids.subtracting(currentUuids) {
            taskbarPanels[uuid]?.orderOut(nil)
            taskbarPanels.removeValue(forKey: uuid)
        }

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
        Windows.refreshTabsAndSpaces()
        let windowsWithFacts = Windows.list.sorted { $0.creationOrder < $1.creationOrder }.map {
            (window: $0, facts: windowFacts($0))
        }
        let facts = windowsWithFacts.map { $0.facts }
        let settings = TaskbarFilterSettings(
            showAllSpaces: Preferences.taskbarSpacesToShow == .all,
            showMinimized: Preferences.taskbarShowMinimizedWindows != .hide,
            showHidden: Preferences.taskbarShowHiddenWindows != .hide,
            showFullscreen: Preferences.taskbarShowFullscreenWindows != .hide,
            showTabs: Preferences.showTabsAsWindows
        )
        for (screenUuid, panel) in taskbarPanels {
            let visibleSpaces = TaskbarTestable.visibleSpaces(Spaces.visibleSpaces,
                screenSpaces: Spaces.screenSpacesMap[screenUuid] ?? [],
                screensHaveSeparateSpaces: NSScreen.screensHaveSeparateSpaces)
            if TaskbarTestable.hidesTaskbar(facts, onScreen: screenUuid, visibleSpaces: visibleSpaces) {
                panel.orderOut(nil)
            } else {
                panel.orderFront(nil)
                let filteredWindows = windowsWithFacts.filter {
                    TaskbarTestable.isShown($0.facts, onScreen: screenUuid,
                        visibleSpaces: visibleSpaces, settings)
                }.map { $0.window }
                panel.updateContents(filteredWindows)
            }
        }
    }

    private func windowFacts(_ window: Window) -> TaskbarWindowFacts {
        return TaskbarWindowFacts(
            isWindowlessApp: window.isWindowlessApp,
            isTabbed: window.isTabbed,
            isMinimized: window.isMinimized,
            isHidden: window.isHidden,
            isFullscreen: window.isFullscreen,
            screenId: window.screenId,
            spaceIds: window.spaceIds
        )
    }

    func updateAppearance() {
        for (_, panel) in taskbarPanels {
            panel.updateAppearance()
        }
    }

    func adjustAllWindows() {
        guard isEnabled else { return }
        for window in Windows.list {
            adjustWindowIfNeeded(window)
        }
    }

    func adjustWindowIfNeeded(_ window: Window) {
        guard isEnabled else { return }
        guard !window.isWindowlessApp else { return }
        guard !window.isFullscreen else { return }
        guard let axUiElement = window.axUiElement else { return }
        guard let position = window.position, let size = window.size else { return }
        guard let screenId = window.screenId else { return }
        guard let screen = NSScreen.screens.first(where: { $0.uuid() == screenId }) else { return }

        let visibleFrameBottomY = TaskbarTestable.visibleFrameBottomY(screen.visibleFrame,
            primaryScreenMaxY: NSMaxY(NSScreen.screens[0].frame))
        guard let newHeight = TaskbarTestable.shrunkHeight(windowY: position.y, windowHeight: size.height,
            visibleFrameBottomY: visibleFrameBottomY, taskbarHeight: Preferences.taskbarHeight)
            else { return }
        BackgroundWork.accessibilityCommandsQueue.addOperation {
            var newSize = CGSize(width: size.width, height: newHeight)
            if let sizeValue = AXValueCreate(.cgSize, &newSize) {
                try? axUiElement.setAttribute(kAXSizeAttribute, sizeValue)
            }

            var newPosition = CGPoint(x: position.x, y: position.y)
            if let posValue = AXValueCreate(.cgPoint, &newPosition) {
                try? axUiElement.setAttribute(kAXPositionAttribute, posValue)
            }
        }
    }
}
