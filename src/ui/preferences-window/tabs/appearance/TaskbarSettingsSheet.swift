import Cocoa

class TaskbarSettingsSheet: SheetWindow {
    override func makeContentView() -> NSView {
        let table = TableGroupView(title: NSLocalizedString("Taskbar", comment: ""), width: SheetWindow.width)

        let heightSlider = LabelAndControl.makeLabelWithSlider("", "taskbarHeight", 24, 64, 9, true, "px", width: 180, extraAction: { _ in
            TaskbarManager.shared.repositionAll()
        })
        let heightIndicator = heightSlider[2] as! NSTextField
        heightIndicator.alignment = .right
        heightIndicator.fit(56, heightIndicator.fittingSize.height)
        table.addRow(leftText: NSLocalizedString("Taskbar height", comment: ""),
            rightViews: [heightSlider[1], heightIndicator])

        let itemHeightSlider = LabelAndControl.makeLabelWithSlider("", "taskbarItemHeight", 18, 48, 7, true, "px", width: 180, extraAction: { _ in
            TaskbarManager.shared.updateContents()
        })
        let itemHeightIndicator = itemHeightSlider[2] as! NSTextField
        itemHeightIndicator.alignment = .right
        itemHeightIndicator.fit(56, itemHeightIndicator.fittingSize.height)
        table.addRow(leftText: NSLocalizedString("Item height", comment: ""),
            rightViews: [itemHeightSlider[1], itemHeightIndicator])

        let iconSizeSlider = LabelAndControl.makeLabelWithSlider("", "taskbarIconSize", 12, 32, 5, true, "px", width: 180, extraAction: { _ in
            TaskbarManager.shared.updateContents()
        })
        let iconSizeIndicator = iconSizeSlider[2] as! NSTextField
        iconSizeIndicator.alignment = .right
        iconSizeIndicator.fit(56, iconSizeIndicator.fittingSize.height)
        table.addRow(leftText: NSLocalizedString("Icon size", comment: ""),
            rightViews: [iconSizeSlider[1], iconSizeIndicator])

        table.fit()
        return table
    }
}
