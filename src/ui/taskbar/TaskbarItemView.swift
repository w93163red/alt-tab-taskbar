import Cocoa

class TaskbarItemView: NSView {
    var window_: Window?
    private var appIcon: NSImageView!
    private var titleLabel: NSTextField!
    private var badgeBackground: NSView!
    private var badgeText: NSTextField!
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var showPreviewTimer: Timer?
    private var iconSize: CGFloat { Preferences.taskbarIconSize }
    private let iconPadding: CGFloat = 6
    private let titlePadding: CGFloat = 4

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    private func setupView() {
        wantsLayer = true
        layer!.cornerRadius = 4
        layer!.masksToBounds = false

        // app icon
        appIcon = NSImageView()
        appIcon.imageScaling = .scaleProportionallyUpOrDown
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(appIcon)

        // title label
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: Preferences.taskbarFontSize)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // notification badge
        badgeBackground = NSView()
        badgeBackground.wantsLayer = true
        badgeBackground.layer!.backgroundColor = NSColor(srgbRed: 1, green: 0.23, blue: 0.19, alpha: 1).cgColor
        badgeBackground.layer!.cornerRadius = 7
        badgeBackground.isHidden = true
        addSubview(badgeBackground)

        badgeText = NSTextField(labelWithString: "")
        badgeText.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        badgeText.textColor = .white
        badgeText.alignment = .center
        badgeBackground.addSubview(badgeText)

        updateBackgroundColor()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override var acceptsFirstResponder: Bool { true }

    // Accept first mouse click even when window is not key
    // This prevents needing to double-click to activate a window
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    // Ensure tracking areas are set up when the view is added to window
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            updateTrackingAreas()
        }
    }

    override func layout() {
        super.layout()

        let iconX = iconPadding
        let iconY = (bounds.height - iconSize) / 2
        appIcon.frame = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)

        let labelX = iconX + iconSize + titlePadding
        let labelWidth = bounds.width - labelX - titlePadding
        let labelHeight: CGFloat = 16
        let labelY = (bounds.height - labelHeight) / 2
        titleLabel.frame = NSRect(x: labelX, y: labelY, width: max(0, labelWidth), height: labelHeight)

        // badge position: top-right of app icon
        if !badgeBackground.isHidden {
            badgeText.sizeToFit()
            let textWidth = max(badgeText.frame.width, 10)
            let badgeWidth = max(textWidth + 4, 14)
            let badgeHeight: CGFloat = 14
            badgeBackground.frame = NSRect(
                x: appIcon.frame.maxX - badgeWidth * 0.6,
                y: appIcon.frame.maxY - badgeHeight * 0.6,
                width: badgeWidth, height: badgeHeight)
            badgeText.frame = NSRect(x: 0, y: 0, width: badgeWidth, height: badgeHeight)
        }
    }

    func updateContent(_ window: Window) {
        window_ = window

        // update icon
        if let icon = window.icon {
            appIcon.image = NSImage(cgImage: icon, size: NSSize(width: iconSize, height: iconSize))
        } else {
            appIcon.image = nil
        }

        // update font size (in case preference changed)
        titleLabel.font = NSFont.systemFont(ofSize: Preferences.taskbarFontSize)

        // update title - show window title or app name
        let title: String
        if window.title.isEmpty {
            title = window.application.localizedName ?? ""
        } else {
            title = window.title
        }
        titleLabel.stringValue = title
        titleLabel.toolTip = title

        // update badge
        let dockLabel = window.dockLabel
        badgeBackground.isHidden = dockLabel == nil || Preferences.hideAppBadges
        if let dockLabel {
            badgeText.stringValue = dockLabel
        }
    }

    func preferredWidth() -> CGFloat {
        let titleWidth = titleLabel.attributedStringValue.size().width
        return iconPadding + iconSize + titlePadding + titleWidth + titlePadding
    }

    private func updateBackgroundColor() {
        if isHovered {
            layer!.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
            layer!.borderWidth = 1
            layer!.borderColor = NSColor.white.withAlphaComponent(0.4).cgColor
        } else {
            layer!.backgroundColor = NSColor.clear.cgColor
            layer!.borderWidth = 0
            layer!.borderColor = nil
        }
    }

    // MARK: - Mouse Events

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateBackgroundColor()
        // show thumbnail preview after a short delay
        if let window = window_ {
            showPreviewTimer?.invalidate()
            showPreviewTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self, self.isHovered else { return }
                TaskbarPreviewPanel.shared.show(for: window, relativeTo: self)
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateBackgroundColor()
        // hide thumbnail preview
        showPreviewTimer?.invalidate()
        showPreviewTimer = nil
        TaskbarPreviewPanel.shared.hide()
    }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        guard let window = window_ else { return }
        // if already focused, minimize; otherwise focus
        if window.application.focusedWindow?.cgWindowId == window.cgWindowId,
           window.application.runningApplication.isActive {
            window.minDemin()
        } else {
            window.focus()
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)),
              window_ != nil else { return }
        let menu = NSMenu()
        let closeItem = NSMenuItem(title: NSLocalizedString("Close", comment: ""), action: #selector(closeWindow), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func closeWindow() {
        window_?.close()
    }
}
