import Cocoa

class TaskbarSettingsSheet: SheetWindow {
    override func makeContentView() -> NSView {
        let table = TableGroupView(title: NSLocalizedString("Taskbar", comment: ""), width: SheetWindow.width)
        let refresh = { TaskbarManager.shared.updateContents() }
        let sliders: [(key: String, label: String, min: Double, max: Double, ticks: Int, unit: String,
                       action: () -> Void)] = [
            ("taskbarHeight", NSLocalizedString("Taskbar height", comment: ""), 24, 64, 9, "px", {
                TaskbarManager.shared.repositionAll()
                TaskbarManager.shared.adjustAllWindows()
            }),
            ("taskbarItemHeight", NSLocalizedString("Item height", comment: ""), 18, 48, 7, "px", refresh),
            ("taskbarIconSize", NSLocalizedString("Icon size", comment: ""), 12, 32, 5, "px", refresh),
            ("taskbarFontSize", NSLocalizedString("Font size", comment: ""), 9, 16, 8, "pt", refresh),
        ]
        for setting in sliders {
            let slider = LabelAndControl.makeLabelWithSlider("", setting.key, setting.min, setting.max,
                setting.ticks, true, setting.unit, width: 180, extraAction: { _ in setting.action() })
            let indicator = slider[2] as! NSTextField
            indicator.alignment = .right
            indicator.fit(56, indicator.fittingSize.height)
            table.addRow(leftText: setting.label, rightViews: [slider[1], indicator])
        }

        table.addNewTable()
        let spacesToShow = LabelAndControl.makeDropdown("taskbarSpacesToShow",
            SpacesToShowPreference.allCases, extraAction: { _ in refresh() })
        table.addRow(leftText: NSLocalizedString("Show windows from Spaces", comment: ""),
            rightViews: [spacesToShow])

        let filters = [
            ("taskbarShowMinimizedWindows", NSLocalizedString("Show minimized windows", comment: "")),
            ("taskbarShowHiddenWindows", NSLocalizedString("Show hidden windows", comment: "")),
            ("taskbarShowFullscreenWindows", NSLocalizedString("Show fullscreen windows", comment: "")),
        ]
        let choices = ShowHowPreference.allCases.filter { $0 != .showAtTheEnd }
        for (key, label) in filters {
            let dropdown = LabelAndControl.makeDropdown(key, choices,
                extraAction: { _ in refresh() })
            table.addRow(leftText: label, rightViews: [dropdown])
        }

        table.fit()
        return table
    }
}
