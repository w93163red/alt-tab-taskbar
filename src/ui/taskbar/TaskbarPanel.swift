import Cocoa

class TaskbarPanel: NSPanel {
    var taskbarView: TaskbarView!
    var screenUuid: ScreenUuid

    init(screenUuid: ScreenUuid) {
        self.screenUuid = screenUuid
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        hidesOnDeactivate = false
        titleVisibility = .hidden
        backgroundColor = .clear
        animationBehavior = .none

        taskbarView = TaskbarView()
        contentView = taskbarView

        // helps filter out this window from the thumbnails
        setAccessibilitySubrole(.unknown)
        setAccessibilityLabel("Taskbar")

        updateAppearance()
    }

    func updateAppearance() {
        hasShadow = true
        appearance = NSAppearance(named: Appearance.currentTheme == .dark ? .vibrantDark : .vibrantLight)
    }

    func positionAtScreenBottom(_ screen: NSScreen) {
        let screenFrame = screen.visibleFrame
        let panelHeight = Preferences.taskbarHeight
        let frame = NSRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: panelHeight
        )
        setFrame(frame, display: true)
    }

    func updateContents(_ windows: [Window]) {
        taskbarView.updateItems(windows)
    }
}
