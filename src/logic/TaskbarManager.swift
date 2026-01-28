import Cocoa

class TaskbarManager {
    static var shared = TaskbarManager()
    var taskbarPanels = [ScreenUuid: TaskbarPanel]()
    var isEnabled = false

    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        createPanelsForAllScreens()
        updateContents()
    }

    func disable() {
        guard isEnabled else { return }
        isEnabled = false
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
        let allWindows = Windows.list.filter { $0.shouldShowTheUser }
        for (screenUuid, panel) in taskbarPanels {
            // filter windows that are on this screen
            let windowsOnScreen = allWindows.filter { $0.screenId == screenUuid }
            panel.updateContents(windowsOnScreen)
        }
    }

    func updateAppearance() {
        for (_, panel) in taskbarPanels {
            panel.updateAppearance()
        }
    }
}
