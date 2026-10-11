import Foundation
import CoreGraphics

struct TaskbarWindowFacts {
    let isWindowlessApp: Bool
    let isTabbed: Bool
    let isMinimized: Bool
    let isHidden: Bool
    let isFullscreen: Bool
    let screenId: ScreenUuid?
    let spaceIds: [CGSSpaceID]
}

struct TaskbarFilterSettings {
    let showAllSpaces: Bool
    let showMinimized: Bool
    let showHidden: Bool
    let showFullscreen: Bool
    let showTabs: Bool
}

class TaskbarTestable {
    static func isShown(_ window: TaskbarWindowFacts, onScreen: ScreenUuid,
                        visibleSpaces: [CGSSpaceID], _ settings: TaskbarFilterSettings) -> Bool {
        guard !window.isWindowlessApp else { return false }
        guard settings.showTabs || !window.isTabbed else { return false }
        guard window.screenId == onScreen else { return false }
        guard settings.showAllSpaces || visibleSpaces.contains(where: { window.spaceIds.contains($0) })
            else { return false }
        guard settings.showMinimized || !window.isMinimized else { return false }
        guard settings.showHidden || !window.isHidden else { return false }
        guard settings.showFullscreen || !window.isFullscreen else { return false }
        return true
    }

    static func visibleSpaces(_ visibleSpaces: [CGSSpaceID], screenSpaces: [CGSSpaceID],
                              screensHaveSeparateSpaces: Bool) -> [CGSSpaceID] {
        guard screensHaveSeparateSpaces else { return visibleSpaces }
        return visibleSpaces.filter { screenSpaces.contains($0) }
    }

    static func hidesTaskbar(_ windows: [TaskbarWindowFacts], onScreen: ScreenUuid,
                             visibleSpaces: [CGSSpaceID]) -> Bool {
        return windows.contains { window in
            !window.isWindowlessApp && window.isFullscreen && window.screenId == onScreen &&
                visibleSpaces.contains(where: { window.spaceIds.contains($0) })
        }
    }

    static func shrunkHeight(windowY: CGFloat, windowHeight: CGFloat, visibleFrameBottomY: CGFloat,
                             taskbarHeight: CGFloat) -> CGFloat? {
        let tolerance: CGFloat = 2
        let taskbarTop = visibleFrameBottomY - taskbarHeight
        let windowBottom = windowY + windowHeight
        guard windowBottom > taskbarTop + tolerance,
              abs(windowBottom - taskbarTop) > tolerance else { return nil }
        let newHeight = taskbarTop - windowY
        guard newHeight > 0, abs(windowHeight - newHeight) > tolerance else { return nil }
        return newHeight
    }

    static func visibleFrameBottomY(_ visibleFrame: CGRect, primaryScreenMaxY: CGFloat) -> CGFloat {
        return primaryScreenMaxY - visibleFrame.maxY + visibleFrame.height
    }

    static func previewSize(thumbnail: CGSize, max: CGSize) -> CGSize {
        let aspectRatio = thumbnail.width / thumbnail.height
        var width = min(max.width, thumbnail.width)
        var height = width / aspectRatio
        if height > max.height {
            height = max.height
            width = height * aspectRatio
        }
        return CGSize(width: width, height: height)
    }

    static func previewX(itemMidX: CGFloat, panelWidth: CGFloat,
                         screenMinX: CGFloat, screenMaxX: CGFloat) -> CGFloat {
        let x = itemMidX - panelWidth / 2
        if x < screenMinX { return screenMinX }
        if x + panelWidth > screenMaxX { return screenMaxX - panelWidth }
        return x
    }

    static func itemFrames(preferredWidths: [CGFloat], itemHeight: CGFloat, barHeight: CGFloat,
                           barWidth: CGFloat) -> (frames: [CGRect], contentWidth: CGFloat) {
        let padding: CGFloat = 8
        let spacing: CGFloat = 4
        var currentX = padding
        let y = (barHeight - itemHeight) / 2
        let frames = preferredWidths.map { preferredWidth in
            let width = min(160, max(48, preferredWidth))
            let frame = CGRect(x: currentX, y: y, width: width, height: itemHeight)
            currentX += width + spacing
            return frame
        }
        return (frames, max(currentX + padding - spacing, barWidth))
    }

    static func displayTitle(windowTitle: String?, appName: String?) -> String {
        guard let windowTitle, !windowTitle.isEmpty else { return appName ?? "" }
        return windowTitle
    }
}
