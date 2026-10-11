import Cocoa

class TaskbarPreviewPanel: NSPanel {
    static let shared = TaskbarPreviewPanel()

    private let previewView = LightImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let containerView = NSVisualEffectView()
    private let maxPreviewWidth: CGFloat = 240
    private let maxPreviewHeight: CGFloat = 160
    private let padding: CGFloat = 8
    private let titleHeight: CGFloat = 20

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    private init() {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        isFloatingPanel = true
        animationBehavior = .none
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        // same level as taskbar, but slightly above
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        collectionBehavior = .canJoinAllSpaces
        setAccessibilitySubrole(.unknown)

        setupContainerView()
        setupPreviewView()
        setupTitleLabel()
    }

    private func setupContainerView() {
        if #available(macOS 10.14, *) {
            containerView.material = .hudWindow
        } else {
            containerView.material = .dark
        }
        containerView.state = .active
        containerView.wantsLayer = true
        containerView.layer!.cornerRadius = 8
        containerView.layer!.masksToBounds = true
        contentView = containerView
    }

    private func setupPreviewView() {
        previewView.wantsLayer = true
        previewView.layer!.cornerRadius = 4
        previewView.layer!.masksToBounds = true
        containerView.addSubview(previewView)
    }

    private func setupTitleLabel() {
        titleLabel.font = NSFont.systemFont(ofSize: 11)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        containerView.addSubview(titleLabel)
    }

    func show(for window: Window, relativeTo itemView: NSView) {
        guard window.cgWindowId != nil else { return }
        guard let thumbnail = window.thumbnail else {
            hide()
            return
        }
        guard let thumbnailSize = thumbnail.size() else {
            hide()
            return
        }

        let previewSize = TaskbarTestable.previewSize(thumbnail: thumbnailSize,
            max: CGSize(width: maxPreviewWidth, height: maxPreviewHeight))
        previewView.updateContents(thumbnail, previewSize)
        previewView.frame = NSRect(x: padding, y: padding + titleHeight,
            width: previewSize.width, height: previewSize.height)

        titleLabel.stringValue = TaskbarTestable.displayTitle(windowTitle: window.title,
            appName: window.application.localizedName)
        titleLabel.frame = NSRect(x: padding, y: padding, width: previewSize.width, height: titleHeight - 4)

        let panelWidth = previewSize.width + padding * 2
        let panelHeight = previewSize.height + titleHeight + padding * 2

        guard let itemWindow = itemView.window else { return }
        let itemFrameInScreen = itemWindow.convertToScreen(itemView.convert(itemView.bounds, to: nil))
        var panelX = itemFrameInScreen.midX - panelWidth / 2
        let panelY = itemFrameInScreen.maxY + 8
        if let screen = itemWindow.screen {
            let screenFrame = screen.visibleFrame
            panelX = TaskbarTestable.previewX(itemMidX: itemFrameInScreen.midX, panelWidth: panelWidth,
                screenMinX: screenFrame.minX, screenMaxX: screenFrame.maxX)
        }

        let panelFrame = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
        setFrame(panelFrame, display: true)

        if !isVisible {
            alphaValue = 0
            orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}
