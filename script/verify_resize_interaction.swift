#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private struct WindowInfo {
    let bounds: CGRect
}

struct CursorSignature: Equatable, CustomStringConvertible {
    let width: Int
    let height: Int
    let hotX: Int
    let hotY: Int

    var description: String {
        "size=\(width)x\(height) hotspot=\(hotX),\(hotY)"
    }
}

private let appName = "CodexUsageNano"
private let bundleIdentifier = "local.codex.CodexUsageNano"
private let openPanelDefaultKey = "debugOpenPanelOnLaunch"
private let tabOriginXKey = "tabOriginX"
private let tabOriginYKey = "tabOriginY"
private let panelOffsetXKey = "panelOffsetX"
private let panelOffsetYKey = "panelOffsetY"

private func windows() -> [WindowInfo] {
    let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return entries.compactMap { entry in
        guard entry[kCGWindowOwnerName as String] as? String == appName,
              let boundsDictionary = entry[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
        else {
            return nil
        }
        return WindowInfo(bounds: bounds)
    }
}

private func panelWindow() -> WindowInfo? {
    windows()
        .filter { $0.bounds.width >= 160 && $0.bounds.height >= 100 }
        .max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
}

@discardableResult
private func run(_ launchPath: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        fputs("FAIL: could not run \(launchPath): \(error)\n", stderr)
        return 127
    }
}

@discardableResult
private func runQuietly(_ launchPath: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        return 127
    }
}

struct DefaultsSnapshot {
    let url: URL
    let didExport: Bool

    static func capture() -> DefaultsSnapshot {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-usage-nano-defaults-\(UUID().uuidString).plist")
        let status = runQuietly("/usr/bin/defaults", ["export", bundleIdentifier, url.path])
        return DefaultsSnapshot(url: url, didExport: status == 0)
    }

    func restore() {
        if didExport {
            runQuietly("/usr/bin/defaults", ["import", bundleIdentifier, url.path])
        } else {
            runQuietly("/usr/bin/defaults", ["delete", bundleIdentifier])
        }
        try? FileManager.default.removeItem(at: url)
    }
}

private func defaultAppPath() -> String {
    let distPath = "dist/\(appName).app"
    if FileManager.default.fileExists(atPath: distPath) {
        return distPath
    }
    return "/Applications/\(appName).app"
}

private func stableTabOrigin() -> CGPoint {
    let visibleFrame = NSScreen.screens
        .map(\.visibleFrame)
        .max { $0.width < $1.width } ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    return CGPoint(x: visibleFrame.midX - 26, y: visibleFrame.midY + 160)
}

private func launchAppWithPanelRequest() {
    let appPath = ProcessInfo.processInfo.environment["CODEX_USAGE_NANO_APP_PATH"] ?? defaultAppPath()
    run("/usr/bin/pkill", ["-x", appName])
    for _ in 0..<20 {
        guard runQuietly("/usr/bin/pgrep", ["-x", appName]) == 0 else { break }
        usleep(100_000)
    }
    let tabOrigin = stableTabOrigin()
    runQuietly("/usr/bin/defaults", ["write", bundleIdentifier, tabOriginXKey, "-float", "\(Double(tabOrigin.x))"])
    runQuietly("/usr/bin/defaults", ["write", bundleIdentifier, tabOriginYKey, "-float", "\(Double(tabOrigin.y))"])
    runQuietly("/usr/bin/defaults", ["delete", bundleIdentifier, panelOffsetXKey])
    runQuietly("/usr/bin/defaults", ["delete", bundleIdentifier, panelOffsetYKey])
    run("/usr/bin/defaults", ["write", bundleIdentifier, openPanelDefaultKey, "-bool", "YES"])
    usleep(100_000)
    let status = run("/usr/bin/open", ["-n", appPath])
    if status != 0 {
        fputs("FAIL: could not open \(appPath).\n", stderr)
        exit(2)
    }
}

private func waitForPanel() -> WindowInfo? {
    for _ in 0..<50 {
        if let panel = panelWindow() {
            return panel
        }
        usleep(100_000)
    }
    return nil
}

private func ensurePanelVisible() -> WindowInfo? {
    launchAppWithPanelRequest()
    return waitForPanel()
}

private func post(_ type: CGEventType, at point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?
        .post(tap: .cghidEventTap)
}

private func signature(for cursor: NSCursor?) -> CursorSignature {
    let size = cursor?.image.size ?? .zero
    let hotSpot = cursor?.hotSpot ?? .zero
    return CursorSignature(
        width: Int(size.width.rounded()),
        height: Int(size.height.rounded()),
        hotX: Int(hotSpot.x.rounded()),
        hotY: Int(hotSpot.y.rounded())
    )
}

private func rightResizeSignature() -> CursorSignature {
    if #available(macOS 15.0, *) {
        return signature(for: NSCursor.frameResize(position: .right, directions: .all))
    }
    return signature(for: .resizeRight)
}

private func moveMouse(to point: CGPoint) {
    CGWarpMouseCursorPosition(point)
    post(.mouseMoved, at: point)
    usleep(180_000)
}

private func drag(from start: CGPoint, to end: CGPoint, steps: Int = 12) {
    moveMouse(to: start)
    post(.leftMouseDown, at: start)
    usleep(80_000)
    for step in 1...steps {
        let fraction = CGFloat(step) / CGFloat(steps)
        let point = CGPoint(
            x: start.x + (end.x - start.x) * fraction,
            y: start.y + (end.y - start.y) * fraction
        )
        post(.leftMouseDragged, at: point)
        usleep(25_000)
    }
    post(.leftMouseUp, at: end)
    usleep(250_000)
}

let defaultsSnapshot = DefaultsSnapshot.capture()
defer { defaultsSnapshot.restore() }

guard let before = ensurePanelVisible() else {
    fputs("FAIL: CodexUsageNano panel window was not visible and could not be opened.\n", stderr)
    exit(2)
}

let inset = Double(ProcessInfo.processInfo.environment["RESIZE_TEST_INSET"] ?? "4") ?? 4
let dragDelta = Double(ProcessInfo.processInfo.environment["RESIZE_TEST_DELTA"] ?? "56") ?? 56
let start = CGPoint(x: before.bounds.maxX - inset, y: before.bounds.midY)
let end = CGPoint(x: start.x + dragDelta, y: start.y)
moveMouse(to: start)
let actualCursor = signature(for: NSCursor.currentSystem)
let expectedCursor = rightResizeSignature()
let showsResizeCursor = actualCursor == expectedCursor
let expectCursor = ProcessInfo.processInfo.environment["RESIZE_TEST_EXPECT_CURSOR"] != "0"

if !showsResizeCursor && !expectCursor {
    print(
        "PASS: tested point does not show a right-edge resize cursor " +
        "inset=\(String(format: "%.1f", inset)) actual=\(actualCursor) expected=\(expectedCursor)."
    )
    exit(0)
}

if !showsResizeCursor {
    fputs(
        "FAIL: tested point did not show the expected right-edge resize cursor " +
        "inset=\(String(format: "%.1f", inset)) actual=\(actualCursor) expected=\(expectedCursor).\n",
        stderr
    )
    exit(1)
}

if !expectCursor {
    fputs(
        "FAIL: tested point unexpectedly showed a right-edge resize cursor " +
        "inset=\(String(format: "%.1f", inset)) actual=\(actualCursor).\n",
        stderr
    )
    exit(1)
}

drag(from: start, to: end)

guard let after = waitForPanel() else {
    fputs("FAIL: CodexUsageNano panel disappeared after resize drag.\n", stderr)
    exit(2)
}

let widthDelta = after.bounds.width - before.bounds.width
let xDelta = after.bounds.minX - before.bounds.minX
let verdict = abs(widthDelta) >= 6

print(
    "right-edge-resize before=\(before.bounds.integral) after=\(after.bounds.integral) " +
    "inset=\(String(format: "%.1f", inset)) " +
    "widthDelta=\(String(format: "%.1f", Double(widthDelta))) " +
    "xDelta=\(String(format: "%.1f", Double(xDelta)))"
)

if verdict {
    print("PASS: right-edge resize cursor drag resized the panel instead of moving it.")
} else {
    fputs("FAIL: right-edge resize cursor drag did not resize the panel reliably.\n", stderr)
    exit(1)
}
