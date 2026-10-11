import Cocoa

class TaskbarView: NSView {
    private var effectView: NSVisualEffectView!
    private var scrollView: NSScrollView!
    private var documentView: NSView!
    private var itemViews = [TaskbarItemView]()
    private var itemHeight: CGFloat { Preferences.taskbarItemHeight }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    private func setupView() {
        wantsLayer = true

        effectView = NSVisualEffectView()
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        if #available(macOS 10.14, *) {
            effectView.material = .hudWindow
        } else {
            effectView.material = .dark
        }
        effectView.wantsLayer = true
        addSubview(effectView)

        scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)

        documentView = NSView()
        documentView.wantsLayer = true
        scrollView.documentView = documentView

        for _ in 0..<20 {
            let itemView = TaskbarItemView()
            itemView.isHidden = true
            documentView.addSubview(itemView)
            itemViews.append(itemView)
        }
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds
        scrollView.frame = bounds
    }

    func updateItems(_ windows: [Window]) {
        while itemViews.count < windows.count {
            let itemView = TaskbarItemView()
            itemView.isHidden = true
            documentView.addSubview(itemView)
            itemViews.append(itemView)
        }

        let preferredWidths = windows.enumerated().map { index, window in
            let itemView = itemViews[index]
            itemView.updateContent(window)
            return itemView.preferredWidth()
        }
        let layout = TaskbarTestable.itemFrames(preferredWidths: preferredWidths, itemHeight: itemHeight,
            barHeight: bounds.height, barWidth: bounds.width)
        for (index, itemView) in itemViews.enumerated() {
            if index < windows.count {
                let newFrame = layout.frames[index]
                let frameChanged = itemView.frame != newFrame
                itemView.frame = newFrame
                itemView.isHidden = false

                if frameChanged {
                    itemView.updateTrackingAreas()
                }
            } else {
                itemView.isHidden = true
            }
        }

        documentView.frame = NSRect(x: 0, y: 0, width: layout.contentWidth, height: bounds.height)
    }
}
