import XCTest

final class TaskbarTests: XCTestCase {
    private let screen: ScreenUuid = "screen" as CFString
    private let otherScreen: ScreenUuid = "other-screen" as CFString

    private func window(isWindowlessApp: Bool = false, isTabbed: Bool = false, isMinimized: Bool = false,
                        isHidden: Bool = false, isFullscreen: Bool = false,
                        screenId: ScreenUuid? = "screen" as CFString,
                        spaceIds: [CGSSpaceID] = [1]) -> TaskbarWindowFacts {
        return TaskbarWindowFacts(isWindowlessApp: isWindowlessApp, isTabbed: isTabbed,
            isMinimized: isMinimized, isHidden: isHidden, isFullscreen: isFullscreen,
            screenId: screenId, spaceIds: spaceIds)
    }

    private func settings(showAllSpaces: Bool = false, showMinimized: Bool = true, showHidden: Bool = true,
                          showFullscreen: Bool = true, showTabs: Bool = false) -> TaskbarFilterSettings {
        return TaskbarFilterSettings(showAllSpaces: showAllSpaces, showMinimized: showMinimized,
            showHidden: showHidden, showFullscreen: showFullscreen, showTabs: showTabs)
    }

    func testIsShownBaselineAndWindowless() {
        XCTAssertTrue(TaskbarTestable.isShown(window(), onScreen: screen, visibleSpaces: [1], settings()))
        XCTAssertFalse(TaskbarTestable.isShown(window(isWindowlessApp: true), onScreen: screen,
            visibleSpaces: [1], settings()))
    }

    func testIsShownTabs() {
        XCTAssertFalse(TaskbarTestable.isShown(window(isTabbed: true), onScreen: screen,
            visibleSpaces: [1], settings()))
        XCTAssertTrue(TaskbarTestable.isShown(window(isTabbed: true), onScreen: screen,
            visibleSpaces: [1], settings(showTabs: true)))
    }

    func testIsShownScreen() {
        XCTAssertFalse(TaskbarTestable.isShown(window(screenId: otherScreen), onScreen: screen,
            visibleSpaces: [1], settings(showAllSpaces: true)))
        XCTAssertFalse(TaskbarTestable.isShown(window(screenId: nil), onScreen: screen,
            visibleSpaces: [1], settings(showAllSpaces: true)))
    }

    func testIsShownSpaces() {
        XCTAssertTrue(TaskbarTestable.isShown(window(spaceIds: [2, 1]), onScreen: screen,
            visibleSpaces: [1], settings()))
        XCTAssertFalse(TaskbarTestable.isShown(window(spaceIds: [2]), onScreen: screen,
            visibleSpaces: [1], settings()))
        XCTAssertTrue(TaskbarTestable.isShown(window(spaceIds: [2]), onScreen: screen,
            visibleSpaces: [1], settings(showAllSpaces: true)))
        XCTAssertFalse(TaskbarTestable.isShown(window(), onScreen: screen, visibleSpaces: [], settings()))
        XCTAssertTrue(TaskbarTestable.isShown(window(spaceIds: []), onScreen: screen,
            visibleSpaces: [], settings(showAllSpaces: true)))
    }

    func testIsShownMinimized() {
        XCTAssertFalse(TaskbarTestable.isShown(window(isMinimized: true), onScreen: screen,
            visibleSpaces: [1], settings(showMinimized: false)))
        XCTAssertTrue(TaskbarTestable.isShown(window(isMinimized: true), onScreen: screen,
            visibleSpaces: [1], settings(showMinimized: true)))
        XCTAssertTrue(TaskbarTestable.isShown(window(), onScreen: screen,
            visibleSpaces: [1], settings(showMinimized: false)))
    }

    func testIsShownHidden() {
        XCTAssertFalse(TaskbarTestable.isShown(window(isHidden: true), onScreen: screen,
            visibleSpaces: [1], settings(showHidden: false)))
        XCTAssertTrue(TaskbarTestable.isShown(window(isHidden: true), onScreen: screen,
            visibleSpaces: [1], settings(showHidden: true)))
        XCTAssertTrue(TaskbarTestable.isShown(window(), onScreen: screen,
            visibleSpaces: [1], settings(showHidden: false)))
    }

    func testIsShownFullscreen() {
        XCTAssertFalse(TaskbarTestable.isShown(window(isFullscreen: true), onScreen: screen,
            visibleSpaces: [1], settings(showFullscreen: false)))
        XCTAssertTrue(TaskbarTestable.isShown(window(isFullscreen: true), onScreen: screen,
            visibleSpaces: [1], settings(showFullscreen: true)))
        XCTAssertTrue(TaskbarTestable.isShown(window(), onScreen: screen,
            visibleSpaces: [1], settings(showFullscreen: false)))
    }

    func testVisibleSpacesPerScreen() {
        XCTAssertEqual(TaskbarTestable.visibleSpaces([1, 5], screenSpaces: [4, 5, 6],
            screensHaveSeparateSpaces: true), [5])
        XCTAssertEqual(TaskbarTestable.visibleSpaces([1, 5], screenSpaces: [],
            screensHaveSeparateSpaces: true), [])
        XCTAssertEqual(TaskbarTestable.visibleSpaces([1], screenSpaces: [],
            screensHaveSeparateSpaces: false), [1])
    }

    func testHidesTaskbarVisibleFullscreen() {
        XCTAssertTrue(TaskbarTestable.hidesTaskbar([window(), window(isFullscreen: true, spaceIds: [2, 1])],
            onScreen: screen, visibleSpaces: [1]))
        XCTAssertFalse(TaskbarTestable.hidesTaskbar([window()], onScreen: screen, visibleSpaces: [1]))
    }

    func testHidesTaskbarOtherSpaceRegression() {
        XCTAssertFalse(TaskbarTestable.hidesTaskbar([window(isFullscreen: true, spaceIds: [2])],
            onScreen: screen, visibleSpaces: [1]))
        XCTAssertFalse(TaskbarTestable.hidesTaskbar([window(isFullscreen: true)],
            onScreen: screen, visibleSpaces: []))
    }

    func testHidesTaskbarOtherScreenAndWindowless() {
        XCTAssertFalse(TaskbarTestable.hidesTaskbar([window(isFullscreen: true, screenId: otherScreen)],
            onScreen: screen, visibleSpaces: [1]))
        XCTAssertFalse(TaskbarTestable.hidesTaskbar([window(isFullscreen: true, screenId: nil)],
            onScreen: screen, visibleSpaces: [1]))
        XCTAssertFalse(TaskbarTestable.hidesTaskbar([window(isWindowlessApp: true, isFullscreen: true)],
            onScreen: screen, visibleSpaces: [1]))
        XCTAssertFalse(TaskbarTestable.hidesTaskbar([], onScreen: screen, visibleSpaces: [1]))
    }

    func testShrunkHeightOverlappingWindow() {
        XCTAssertEqual(TaskbarTestable.shrunkHeight(windowY: 100, windowHeight: 900,
            visibleFrameBottomY: 1000, taskbarHeight: 40), 860)
    }

    func testShrunkHeightJustOutsideTolerance() {
        XCTAssertEqual(TaskbarTestable.shrunkHeight(windowY: 100, windowHeight: 863,
            visibleFrameBottomY: 1000, taskbarHeight: 40), 860)
    }

    func testShrunkHeightAlreadyAdjustedAndTolerance() {
        XCTAssertNil(TaskbarTestable.shrunkHeight(windowY: 100, windowHeight: 860,
            visibleFrameBottomY: 1000, taskbarHeight: 40))
        XCTAssertNil(TaskbarTestable.shrunkHeight(windowY: 100, windowHeight: 858,
            visibleFrameBottomY: 1000, taskbarHeight: 40))
        XCTAssertNil(TaskbarTestable.shrunkHeight(windowY: 100, windowHeight: 862,
            visibleFrameBottomY: 1000, taskbarHeight: 40))
        XCTAssertNil(TaskbarTestable.shrunkHeight(windowY: 100, windowHeight: 861,
            visibleFrameBottomY: 1000, taskbarHeight: 40))
    }

    func testShrunkHeightWindowAboveOrBelowTaskbarTop() {
        XCTAssertNil(TaskbarTestable.shrunkHeight(windowY: 100, windowHeight: 700,
            visibleFrameBottomY: 1000, taskbarHeight: 40))
        XCTAssertNil(TaskbarTestable.shrunkHeight(windowY: 970, windowHeight: 100,
            visibleFrameBottomY: 1000, taskbarHeight: 40))
        XCTAssertNil(TaskbarTestable.shrunkHeight(windowY: 960, windowHeight: 100,
            visibleFrameBottomY: 1000, taskbarHeight: 40))
    }

    func testVisibleFrameBottomY() {
        XCTAssertEqual(TaskbarTestable.visibleFrameBottomY(CGRect(x: 0, y: 30, width: 1440, height: 850),
            primaryScreenMaxY: 900), 870)
        XCTAssertEqual(TaskbarTestable.visibleFrameBottomY(
            CGRect(x: 1440, y: -300, width: 1920, height: 1050), primaryScreenMaxY: 900), 1200)
    }

    func testPreviewSize() {
        XCTAssertEqual(TaskbarTestable.previewSize(thumbnail: CGSize(width: 1920, height: 1080),
            max: CGSize(width: 240, height: 160)), CGSize(width: 240, height: 135))
        XCTAssertEqual(TaskbarTestable.previewSize(thumbnail: CGSize(width: 1000, height: 2000),
            max: CGSize(width: 240, height: 160)), CGSize(width: 80, height: 160))
        XCTAssertEqual(TaskbarTestable.previewSize(thumbnail: CGSize(width: 100, height: 50),
            max: CGSize(width: 240, height: 160)), CGSize(width: 100, height: 50))
    }

    func testPreviewX() {
        XCTAssertEqual(TaskbarTestable.previewX(itemMidX: 500, panelWidth: 256,
            screenMinX: 100, screenMaxX: 1100), 372)
        XCTAssertEqual(TaskbarTestable.previewX(itemMidX: 150, panelWidth: 256,
            screenMinX: 100, screenMaxX: 1100), 100)
        XCTAssertEqual(TaskbarTestable.previewX(itemMidX: 1050, panelWidth: 256,
            screenMinX: 100, screenMaxX: 1100), 844)
        XCTAssertEqual(TaskbarTestable.previewX(itemMidX: 500, panelWidth: 1200,
            screenMinX: 100, screenMaxX: 1100), 100)
    }

    func testItemFrames() {
        let layout = TaskbarTestable.itemFrames(preferredWidths: [20, 100, 200], itemHeight: 24,
            barHeight: 40, barWidth: 500)
        XCTAssertEqual(layout.frames, [
            CGRect(x: 8, y: 8, width: 48, height: 24),
            CGRect(x: 60, y: 8, width: 100, height: 24),
            CGRect(x: 164, y: 8, width: 160, height: 24),
        ])
        XCTAssertEqual(layout.contentWidth, 500)
        XCTAssertEqual(TaskbarTestable.itemFrames(preferredWidths: [100], itemHeight: 24,
            barHeight: 50, barWidth: 500).frames, [CGRect(x: 8, y: 13, width: 100, height: 24)])
        let wideLayout = TaskbarTestable.itemFrames(preferredWidths: [20, 100, 200], itemHeight: 24,
            barHeight: 40, barWidth: 300)
        XCTAssertEqual(wideLayout.contentWidth, 332)
        let emptyLayout = TaskbarTestable.itemFrames(preferredWidths: [], itemHeight: 24,
            barHeight: 40, barWidth: 500)
        XCTAssertEqual(emptyLayout.frames, [])
        XCTAssertEqual(emptyLayout.contentWidth, 500)
        XCTAssertEqual(TaskbarTestable.itemFrames(preferredWidths: [], itemHeight: 24,
            barHeight: 40, barWidth: 0).contentWidth, 12)
    }

    func testDisplayTitle() {
        XCTAssertEqual(TaskbarTestable.displayTitle(windowTitle: "Window", appName: "App"), "Window")
        XCTAssertEqual(TaskbarTestable.displayTitle(windowTitle: "", appName: "App"), "App")
        XCTAssertEqual(TaskbarTestable.displayTitle(windowTitle: nil, appName: "App"), "App")
        XCTAssertEqual(TaskbarTestable.displayTitle(windowTitle: "Window", appName: nil), "Window")
        XCTAssertEqual(TaskbarTestable.displayTitle(windowTitle: "", appName: nil), "")
        XCTAssertEqual(TaskbarTestable.displayTitle(windowTitle: nil, appName: nil), "")
    }
}
