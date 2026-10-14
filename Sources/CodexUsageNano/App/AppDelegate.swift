import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let store = UsageStore(service: CodexUsageService())
    private let tabPresentation = EdgeTabPresentationState()
    private let panelOffsetStore = PanelOffsetStore()
    private let panelSize = TabPositioning.defaultPanelSize
    private let tabOriginXKey = "tabOriginX"
    private let tabOriginYKey = "tabOriginY"
    private let debugOpenPanelOnLaunchKey = "debugOpenPanelOnLaunch"
    private var panel: NSPanel?
    private var tabPanel: NSPanel?
    private var isTabDragging = false
    private var isPositioningPanel = false
    private var isPanelLiveResizing = false
    private var hadSavedPanelOffsetAtResizeStart = false
    private var suppressHoverExpansionUntilExit = false
    private var didExitDuringDrag = false
    private var collapsedFrameBeforeHover: NSRect?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createPanel()
        createTabPanel()
        if CommandLine.arguments.contains("--self-test-hover") {
            let initial = tabPanel!.frame
            handleTabHoverChanged(true)
            FileHandle.standardOutput.write(Data("hover mode=\(tabPresentation.mode) frame=\(tabPanel!.frame) expected=\(EdgeTabPresentation.expandedSize) initial=\(initial)\n".utf8))
            precondition(tabPresentation.mode == .expanded)
            precondition(tabPanel!.frame.size == EdgeTabPresentation.expandedSize)
            handleTabHoverChanged(false, mouseLocation: NSPoint(x: -100000, y: -100000))
            FileHandle.standardOutput.write(Data("exit mode=\(tabPresentation.mode) frame=\(tabPanel!.frame) initial=\(initial)\n".utf8))
            precondition(tabPresentation.mode == .collapsed)
            precondition(tabPanel!.frame.origin == initial.origin)
            precondition(tabPanel!.frame.size == EdgeTabPresentation.collapsedSize)
            print("PASS: hover opens summary and exit restores the original small tab")
            NSApp.terminate(nil)
            return
        }
        store.start()
        showPanelOnLaunchIfRequested()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        suppressHoverExpansionUntilExit = true
        setTabMode(.collapsed)
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            store.refresh()
            if panel.alphaValue <= 0.01 {
                setPanelOpacity(1, showsHUD: false)
            }
            showPanel(context: "toggle")
        }
    }

    private func showPanelOnLaunchIfRequested() {
        guard UserDefaults.standard.bool(forKey: debugOpenPanelOnLaunchKey) else { return }
        UserDefaults.standard.removeObject(forKey: debugOpenPanelOnLaunchKey)
        DispatchQueue.main.async { [weak self] in
            self?.store.refresh()
            self?.showPanel(context: "debug-open-panel-on-launch")
        }
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: frameNearTab(for: panelSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .none
        panel.level = TabPositioning.windowLevel
        panel.minSize = NSSize(width: 180, height: 64)
        panel.maxSize = NSSize(width: 560, height: 320)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self
        let panelView = OpacityAdjustingHostingView(rootView: WidgetView(store: store))
        panelView.onOpacityDelta = { [weak self] deltaY in
            self?.adjustPanelOpacity(deltaY: deltaY, context: "panel-scroll")
        }
        panelView.onDoubleClick = { [weak self] in
            self?.resetPanelSizeAndShow()
        }
        panel.contentView = panelView
        self.panel = panel
    }

    private func createTabPanel() {
        let tabPanel = NSPanel(
            contentRect: frameForTab(),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        tabPanel.isOpaque = false
        tabPanel.backgroundColor = .clear
        tabPanel.hasShadow = true
        tabPanel.animationBehavior = .none
        tabPanel.level = TabPositioning.windowLevel
        tabPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let tabView = DraggableTabHostingView(rootView: EdgeTabView(store: store, presentation: tabPresentation))
        tabView.onClick = { [weak self] in
            self?.togglePanel()
        }
        tabView.onDoubleClick = { [weak self] in
            self?.resetPanelPositionOpacityAndShow()
        }
        tabView.onOpacityDelta = { [weak self] deltaY in
            self?.adjustPanelOpacity(deltaY: deltaY, context: "tab-scroll")
        }
        tabView.onContextMenu = { [weak self, weak tabView] event in
            guard let tabView else { return }
            self?.showTabMenu(for: tabView, event: event)
        }
        tabView.onHoverChanged = { [weak self] isHovering in
            self?.handleTabHoverChanged(isHovering)
        }
        tabView.onDragStarted = { [weak self] in
            self?.handleTabDragStarted()
        }
        tabView.onMove = { [weak self] origin in
            self?.moveTab(to: origin)
        }
        tabView.onMoveEnded = { [weak self] in
            self?.handleTabDragEnded()
        }
        tabPanel.contentView = tabView
        tabPanel.orderFrontRegardless()
        self.tabPanel = tabPanel
    }

    private func showTabMenu(for view: NSView, event: NSEvent) {
        let menu = NSMenu()
        let toggleTitle = panel?.isVisible == true ? "收起详情" : "固定显示详情"
        menu.addItem(NSMenuItem(title: toggleTitle, action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "刷新额度", action: #selector(refreshUsage), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 Codex Pace", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func refreshUsage() {
        store.refresh()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func moveTab(to proposedOrigin: NSPoint) {
        guard let tabPanel else { return }
        tabPanel.setFrameOrigin(constrainedOrigin(proposedOrigin, size: tabPanel.frame.size))

        if panel?.isVisible == true {
            setPanelFrame(frameNearTab(for: panel?.frame.size ?? panelSize))
            alignPanelToVisibleTab(context: "moveTab")
        }
    }

    private func handleTabHoverChanged(_ isHovering: Bool, mouseLocation: NSPoint = NSEvent.mouseLocation) {
        if isHovering {
            guard !isTabDragging, !suppressHoverExpansionUntilExit, panel?.isVisible != true else { return }
            setTabMode(.expanded)
        } else {
            if tabPresentation.mode == .expanded,
               tabPanel?.frame.contains(mouseLocation) == true { return }
            if isTabDragging {
                didExitDuringDrag = true
            }
            suppressHoverExpansionUntilExit = false
            setTabMode(.collapsed)
        }
    }

    private func handleTabDragStarted() {
        isTabDragging = true
        didExitDuringDrag = false
        suppressHoverExpansionUntilExit = true
        setTabMode(.dragging)
    }

    private func handleTabDragEnded() {
        isTabDragging = false
        suppressHoverExpansionUntilExit = !didExitDuringDrag
        didExitDuringDrag = false
        setTabMode(.collapsed)
        saveTabPosition()
    }

    private func setTabMode(_ mode: EdgeTabPresentationMode) {
        let previousMode = tabPresentation.mode
        tabPresentation.mode = mode
        guard let tabPanel else { return }
        if mode == .expanded, previousMode != .expanded {
            collapsedFrameBeforeHover = tabPanel.frame
        }
        let size = EdgeTabPresentation.size(for: mode)
        guard tabPanel.frame.size != size else {
            tabPanel.orderFrontRegardless()
            return
        }

        let origin: NSPoint
        if mode != .expanded, let saved = collapsedFrameBeforeHover {
            origin = constrainedOrigin(saved.origin, size: size)
            collapsedFrameBeforeHover = nil
        } else {
            origin = resizedTabOrigin(from: tabPanel.frame, to: size)
        }
        tabPanel.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
        if panel?.isVisible == true {
            setPanelFrame(frameNearTab(for: panel?.frame.size ?? panelSize))
            alignPanelToVisibleTab(context: "setTabMode")
        }
        tabPanel.orderFrontRegardless()
    }

    private func showPanel(context: String) {
        guard let panel else { return }
        setPanelFrame(frameNearTab(for: panel.frame.size))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        tabPanel?.orderFrontRegardless()
        alignPanelToVisibleTab(context: context)
    }

    private func adjustPanelOpacity(deltaY: CGFloat, context: String) {
        guard let panel else { return }
        if !panel.isVisible {
            store.refresh()
            showPanel(context: context)
        } else {
            tabPanel?.orderFrontRegardless()
        }

        let nextOpacity = TabPositioning.adjustedOpacity(
            current: panel.alphaValue,
            scrollDeltaY: deltaY
        )
        setPanelOpacity(nextOpacity, showsHUD: true)
    }

    private func resetPanelPositionOpacityAndShow() {
        panelOffsetStore.reset()
        setPanelOpacity(1, showsHUD: true)
        store.refresh()
        showPanel(context: "tab-double-click")
    }

    private func resetPanelSizeAndShow() {
        guard let panel else { return }
        store.refresh()
        let frame = NSRect(
            origin: resetPanelOrigin(for: panelSize, currentFrame: panel.frame),
            size: panelSize
        )
        setPanelFrame(frame)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        tabPanel?.orderFrontRegardless()
        alignPanelToVisibleTab(context: "panel-double-click")
    }

    private func setPanelOpacity(_ opacity: CGFloat, showsHUD: Bool) {
        panel?.alphaValue = opacity
        if showsHUD {
            store.showOpacityHUD(percent: TabPositioning.opacityPercent(for: opacity))
        }
    }

    private func saveTabPosition() {
        guard let tabPanel else { return }
        let origin = tabPanel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: tabOriginXKey)
        UserDefaults.standard.set(origin.y, forKey: tabOriginYKey)
    }

    private func frameNearTab(for size: NSSize) -> NSRect {
        let tabFrame = tabPanel?.frame ?? frameForTab()
        return frame(for: size, anchoredTo: tabFrame)
    }

    private func frame(for size: NSSize, anchoredTo anchor: NSRect) -> NSRect {
        let visibleFrame = visibleFrame(containing: anchor)
        let screenFrame = screenFrame(containing: anchor)
        return NSRect(
            origin: TabPositioning.panelOrigin(
                size: size,
                anchor: anchor,
                savedOffset: savedPanelOffset(),
                visibleFrame: visibleFrame,
                screenFrame: screenFrame
            ),
            size: size
        )
    }

    private func frameForTab() -> NSRect {
        let tabSize = EdgeTabPresentation.collapsedSize
        if let savedOrigin = savedTabOrigin() {
            return NSRect(
                origin: constrainedOrigin(savedOrigin, size: tabSize),
                size: tabSize
            )
        }

        let screenFrame = widestVisibleFrame()
        let origin = NSPoint(
            x: max(screenFrame.minX + 8, screenFrame.maxX - tabSize.width - 8),
            y: max(screenFrame.minY + 8, screenFrame.midY - tabSize.height / 2)
        )
        return NSRect(origin: origin, size: tabSize)
    }

    private func savedTabOrigin() -> NSPoint? {
        guard UserDefaults.standard.object(forKey: tabOriginXKey) != nil,
              UserDefaults.standard.object(forKey: tabOriginYKey) != nil
        else {
            return nil
        }
        return NSPoint(
            x: UserDefaults.standard.double(forKey: tabOriginXKey),
            y: UserDefaults.standard.double(forKey: tabOriginYKey)
        )
    }

    private func constrainedOrigin(_ origin: NSPoint, size: NSSize) -> NSPoint {
        let rect = NSRect(origin: origin, size: size)
        return TabPositioning.constrainedOrigin(
            origin,
            size: size,
            visibleFrame: visibleFrame(containing: rect),
            screenFrame: screenFrame(containing: rect)
        )
    }

    private func setPanelFrame(_ frame: NSRect) {
        guard let panel else { return }
        isPositioningPanel = true
        panel.setFrame(frame, display: true)
        isPositioningPanel = false
        saveCorrectedPanelOffsetIfNeeded(for: panel.frame)
    }

    private func handlePanelDidMove(_ notification: Notification) {
        guard let movedWindow = notification.object as? NSWindow,
              movedWindow === panel,
              let panel,
              !isPositioningPanel,
              panel.isVisible
        else {
            return
        }

        constrainPanelFrameIfNeeded(panel)
        guard PanelOffsetPersistence.shouldSaveMoveOffset(isLiveResizing: isPanelLiveResizing) else { return }
        savePanelOffset(for: panel.frame)
    }

    func windowDidMove(_ notification: Notification) {
        handlePanelDidMove(notification)
    }

    func windowDidResize(_ notification: Notification) {
        guard let resizedWindow = notification.object as? NSWindow,
              resizedWindow === panel,
              let panel,
              !isPanelLiveResizing,
              panel.isVisible
        else {
            return
        }
        guard PanelOffsetPersistence.shouldSaveResizeOffset(
            hadSavedOffsetAtResizeStart: hasSavedPanelOffset
        ) else { return }
        savePanelOffset(for: panel.frame)
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        guard let resizedWindow = notification.object as? NSWindow,
              resizedWindow === panel
        else {
            return
        }
        hadSavedPanelOffsetAtResizeStart = hasSavedPanelOffset
        isPanelLiveResizing = true
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let resizedWindow = notification.object as? NSWindow,
              resizedWindow === panel,
              let panel
        else {
            return
        }
        let shouldSaveOffset = PanelOffsetPersistence.shouldSaveResizeOffset(
            hadSavedOffsetAtResizeStart: hadSavedPanelOffsetAtResizeStart
        )
        constrainPanelFrameIfNeeded(panel)
        DispatchQueue.main.async { [weak self] in
            self?.isPanelLiveResizing = false
            self?.hadSavedPanelOffsetAtResizeStart = false
        }
        guard shouldSaveOffset else { return }
        savePanelOffset(for: panel.frame)
    }

    private func constrainPanelFrameIfNeeded(_ panel: NSWindow) {
        let correctedFrame = constrainedPanelFrame(panel.frame)
        guard correctedFrame.origin != panel.frame.origin else { return }
        isPositioningPanel = true
        panel.setFrame(correctedFrame, display: true)
        isPositioningPanel = false
    }

    private func constrainedPanelFrame(_ frame: NSRect) -> NSRect {
        let anchor = tabPanel?.frame ?? frameForTab()
        return NSRect(
            origin: TabPositioning.constrainedPanelOrigin(
                frame.origin,
                size: frame.size,
                visibleFrame: visibleFrame(containing: anchor),
                screenFrame: screenFrame(containing: anchor)
            ),
            size: frame.size
        )
    }

    private func resetPanelOrigin(for size: NSSize, currentFrame: NSRect) -> NSPoint {
        let anchor = tabPanel?.frame ?? frameForTab()
        let referenceFrame = hasSavedPanelOffset ? currentFrame : anchor
        return TabPositioning.panelResetOrigin(
            size: size,
            currentFrame: currentFrame,
            anchor: anchor,
            hasSavedOffset: hasSavedPanelOffset,
            visibleFrame: visibleFrame(containing: referenceFrame),
            screenFrame: screenFrame(containing: referenceFrame)
        )
    }

    private var hasSavedPanelOffset: Bool {
        panelOffsetStore.hasSavedOffset
    }

    private func savedPanelOffset() -> NSSize? {
        panelOffsetStore.load()
    }

    private func saveCorrectedPanelOffsetIfNeeded(for panelFrame: NSRect) {
        guard hasSavedPanelOffset else { return }
        savePanelOffset(for: panelFrame)
    }

    private func savePanelOffset(for panelFrame: NSRect) {
        let anchor = tabPanel?.frame ?? frameForTab()
        let offset = TabPositioning.panelOffset(panelOrigin: panelFrame.origin, anchor: anchor)
        panelOffsetStore.save(offset)
    }

    private func resizedTabOrigin(from frame: NSRect, to size: NSSize) -> NSPoint {
        TabPositioning.resizedOrigin(
            from: frame,
            to: size,
            visibleFrame: visibleFrame(containing: frame),
            screenFrame: screenFrame(containing: frame)
        )
    }

    private func screenFrame(containing rect: NSRect) -> NSRect {
        NSScreen.screens
            .map(\.frame)
            .first { $0.intersects(rect) } ?? widestScreenFrame()
    }

    private func visibleFrame(containing rect: NSRect) -> NSRect {
        NSScreen.screens
            .map(\.visibleFrame)
            .first { $0.intersects(rect) } ?? widestVisibleFrame()
    }

    private func widestVisibleFrame() -> NSRect {
        let screenFrame = NSScreen.screens
            .map(\.visibleFrame)
            .max { $0.width < $1.width } ?? .zero
        return screenFrame
    }

    private func widestScreenFrame() -> NSRect {
        let screenFrame = NSScreen.screens
            .map(\.frame)
            .max { $0.width < $1.width } ?? .zero
        return screenFrame
    }

    private func alignPanelToVisibleTab(context: String) {
        DispatchQueue.main.async { [weak self] in
            self?.alignPanelToVisibleTabNow(context: context)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.alignPanelToVisibleTabNow(context: "\(context):followup")
        }
    }

    private func alignPanelToVisibleTabNow(context: String) {
        guard let panel, let tabPanel, panel.isVisible else { return }
        guard !hasSavedPanelOffset else { return }
        let visibleFrame = visibleFrame(containing: tabPanel.frame)
        guard tabPanel.frame.maxY > visibleFrame.maxY else { return }
        guard let tabBounds = RuntimeWindowFrames.bounds(for: tabPanel.windowNumber),
              let panelBounds = RuntimeWindowFrames.bounds(for: panel.windowNumber)
        else {
            FrameDiagnostics.log(context: context, tabFrame: tabPanel.frame, panelFrame: panel.frame)
            return
        }

        let actualGap = panelBounds.minY - tabBounds.maxY
        let delta = actualGap - TabPositioning.panelTopGap
        FrameDiagnostics.log(
            context: context,
            tabFrame: tabPanel.frame,
            panelFrame: panel.frame,
            tabBounds: tabBounds,
            panelBounds: panelBounds,
            delta: delta
        )
        guard abs(delta) > 1 else { return }
        isPositioningPanel = true
        panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x, y: panel.frame.origin.y + delta))
        isPositioningPanel = false
    }
}

enum RuntimeWindowFrames {
    static func bounds(for windowNumber: Int) -> NSRect? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        for window in windows {
            guard window[kCGWindowNumber as String] as? Int == windowNumber,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds)
            else { continue }
            return NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        }
        return nil
    }
}

enum PanelOffsetPersistence {
    static func shouldSaveMoveOffset(isLiveResizing: Bool) -> Bool {
        !isLiveResizing
    }

    static func shouldSaveResizeOffset(hadSavedOffsetAtResizeStart: Bool) -> Bool {
        hadSavedOffsetAtResizeStart
    }
}

enum FrameDiagnostics {
    static func log(
        context: String,
        tabFrame: NSRect,
        panelFrame: NSRect,
        tabBounds: NSRect? = nil,
        panelBounds: NSRect? = nil,
        delta: CGFloat? = nil
    ) {
        let message = [
            "context=\(context)",
            "tabFrame=\(NSStringFromRect(tabFrame))",
            "panelFrame=\(NSStringFromRect(panelFrame))",
            "tabBounds=\(tabBounds.map(NSStringFromRect) ?? "nil")",
            "panelBounds=\(panelBounds.map(NSStringFromRect) ?? "nil")",
            "delta=\(delta.map { String(format: "%.2f", Double($0)) } ?? "nil")"
        ].joined(separator: " ")
        NSLog("CodexUsageNanoFrame %@", message)
        appendToFile(message)
    }

    private static func appendToFile(_ message: String) {
        let url = URL(fileURLWithPath: "/private/tmp/codex-usage-nano-frames.log")
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}

enum TabPositioning {
    static let windowLevel = NSWindow.Level.statusBar
    static let edgePadding: CGFloat = 8
    static let panelTopGap: CGFloat = 4
    static let panelDesignSize = NSSize(width: 180, height: 64)
    static let defaultPanelDisplayScale: CGFloat = 1
    static var defaultPanelSize: NSSize {
        NSSize(
            width: panelDesignSize.width * defaultPanelDisplayScale,
            height: panelDesignSize.height * defaultPanelDisplayScale
        )
    }

    static func constrainedOrigin(
        _ origin: NSPoint,
        size: NSSize,
        visibleFrame: NSRect,
        screenFrame: NSRect
    ) -> NSPoint {
        NSPoint(
            x: min(max(visibleFrame.minX + edgePadding, origin.x), visibleFrame.maxX - size.width - edgePadding),
            y: min(max(visibleFrame.minY + edgePadding, origin.y), screenFrame.maxY - size.height)
        )
    }

    static func panelOrigin(
        size: NSSize,
        anchor: NSRect,
        savedOffset: NSSize? = nil,
        visibleFrame: NSRect,
        screenFrame: NSRect
    ) -> NSPoint {
        let offset = savedOffset ?? defaultPanelOffset(size: size, anchor: anchor)
        let proposedOrigin = NSPoint(
            x: anchor.minX + offset.width,
            y: anchor.minY + offset.height
        )
        return constrainedPanelOrigin(
            proposedOrigin,
            size: size,
            visibleFrame: visibleFrame,
            screenFrame: screenFrame
        )
    }

    static func panelOffset(panelOrigin: NSPoint, anchor: NSRect) -> NSSize {
        NSSize(
            width: panelOrigin.x - anchor.minX,
            height: panelOrigin.y - anchor.minY
        )
    }

    static func constrainedPanelOrigin(
        _ origin: NSPoint,
        size: NSSize,
        visibleFrame: NSRect,
        screenFrame: NSRect
    ) -> NSPoint {
        NSPoint(
            x: min(max(visibleFrame.minX + edgePadding, origin.x), visibleFrame.maxX - size.width - edgePadding),
            y: min(max(screenFrame.minY + edgePadding, origin.y), screenFrame.maxY - size.height - edgePadding)
        )
    }

    static func panelResetOrigin(
        size: NSSize,
        currentFrame: NSRect,
        anchor: NSRect,
        hasSavedOffset: Bool,
        visibleFrame: NSRect,
        screenFrame: NSRect
    ) -> NSPoint {
        guard hasSavedOffset else {
            return panelOrigin(
                size: size,
                anchor: anchor,
                visibleFrame: visibleFrame,
                screenFrame: screenFrame
            )
        }

        let proposedOrigin = NSPoint(
            x: currentFrame.midX - size.width / 2,
            y: currentFrame.midY - size.height / 2
        )
        return constrainedPanelOrigin(
            proposedOrigin,
            size: size,
            visibleFrame: visibleFrame,
            screenFrame: screenFrame
        )
    }

    private static func defaultPanelOffset(size: NSSize, anchor: NSRect) -> NSSize {
        NSSize(
            width: anchor.width / 2 - size.width / 2,
            height: -panelTopGap - size.height
        )
    }

    static func resizedOrigin(
        from currentFrame: NSRect,
        to size: NSSize,
        visibleFrame: NSRect,
        screenFrame: NSRect
    ) -> NSPoint {
        let keepsRightEdge = currentFrame.midX >= visibleFrame.midX
        let proposedX = keepsRightEdge ? currentFrame.maxX - size.width : currentFrame.minX
        let proposedY = resizedY(from: currentFrame, toHeight: size.height, visibleFrame: visibleFrame, screenFrame: screenFrame)
        return constrainedOrigin(
            NSPoint(x: proposedX, y: proposedY),
            size: size,
            visibleFrame: visibleFrame,
            screenFrame: screenFrame
        )
    }

    static func adjustedOpacity(current: CGFloat, scrollDeltaY: CGFloat) -> CGFloat {
        min(max(current + scrollDeltaY / 500, 0), 1)
    }

    static func opacityPercent(for opacity: CGFloat) -> Int {
        Int((min(max(opacity, 0), 1) * 100).rounded())
    }

    private static func resizedY(
        from currentFrame: NSRect,
        toHeight height: CGFloat,
        visibleFrame: NSRect,
        screenFrame: NSRect
    ) -> CGFloat {
        let tolerance: CGFloat = 0.5
        let bottomLimit = visibleFrame.minY + 8
        if currentFrame.maxY >= screenFrame.maxY - tolerance {
            return currentFrame.maxY - height
        }
        if currentFrame.minY <= bottomLimit + tolerance {
            return currentFrame.minY
        }
        return currentFrame.midY - height / 2
    }
}
