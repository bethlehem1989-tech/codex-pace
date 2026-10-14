#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private struct WindowInfo {
    let bounds: CGRect
}

private let appName = "CodexUsageNano"
private let bundleIdentifier = "local.codex.CodexUsageNano"
private let openPanelDefaultKey = "debugOpenPanelOnLaunch"
private let tabOriginXKey = "tabOriginX"
private let tabOriginYKey = "tabOriginY"
private let panelOffsetXKey = "panelOffsetX"
private let panelOffsetYKey = "panelOffsetY"

private struct CursorSignature: Equatable, CustomStringConvertible {
    let width: Int
    let height: Int
    let hotX: Int
    let hotY: Int

    var description: String {
        "size=\(width)x\(height) hotspot=\(hotX),\(hotY)"
    }
}

private enum Placement: String, CaseIterable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    var frameResizePosition: NSCursor.FrameResizePosition {
        switch self {
        case .topLeft:
            return .topLeft
        case .top:
            return .top
        case .topRight:
            return .topRight
        case .right:
            return .right
        case .bottomRight:
            return .bottomRight
        case .bottom:
            return .bottom
        case .bottomLeft:
            return .bottomLeft
        case .left:
            return .left
        }
    }

    func point(in bounds: CGRect) -> CGPoint {
        let inset: CGFloat = 2
        switch self {
        case .topLeft:
            return CGPoint(x: bounds.minX + inset, y: bounds.minY + inset)
        case .top:
            return CGPoint(x: bounds.midX, y: bounds.minY + inset)
        case .topRight:
            return CGPoint(x: bounds.maxX - inset, y: bounds.minY + inset)
        case .right:
            return CGPoint(x: bounds.maxX - inset, y: bounds.midY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX - inset, y: bounds.maxY - inset)
        case .bottom:
            return CGPoint(x: bounds.midX, y: bounds.maxY - inset)
        case .bottomLeft:
            return CGPoint(x: bounds.minX + inset, y: bounds.maxY - inset)
        case .left:
            return CGPoint(x: bounds.minX + inset, y: bounds.midY)
        }
    }
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

@available(macOS 15.0, *)
private func expectedSignature(for placement: Placement) -> CursorSignature {
    signature(for: NSCursor.frameResize(position: placement.frameResizePosition, directions: .all))
}

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

private func postMouseMove(to point: CGPoint) {
    CGWarpMouseCursorPosition(point)
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
        .post(tap: .cghidEventTap)
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
    let status = run("/usr/bin/open", ["-n", appPath])
    if status != 0 {
        fputs("FAIL: could not open \(appPath).\n", stderr)
        exit(2)
    }
}

private func waitForPanel() -> WindowInfo? {
    for _ in 0..<40 {
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

let defaultsSnapshot = DefaultsSnapshot.capture()
defer { defaultsSnapshot.restore() }

guard #available(macOS 15.0, *) else {
    fputs("SKIP: NSCursor.frameResize requires macOS 15 or newer for exact cursor verification.\n", stderr)
    exit(77)
}

guard let panel = ensurePanelVisible() else {
    fputs("FAIL: CodexUsageNano panel window was not visible and could not be opened.\n", stderr)
    exit(2)
}

let center = CGPoint(x: panel.bounds.midX, y: panel.bounds.midY)
var failures: [String] = []

for placement in Placement.allCases {
    postMouseMove(to: center)
    usleep(120_000)
    let point = placement.point(in: panel.bounds)
    postMouseMove(to: point)
    usleep(220_000)

    let actual = signature(for: NSCursor.currentSystem)
    let expected = expectedSignature(for: placement)
    let verdict = actual == expected ? "PASS" : "FAIL"
    print("\(verdict) \(placement.rawValue) point=\(Int(point.x)),\(Int(point.y)) actual=\(actual) expected=\(expected)")
    if actual != expected {
        failures.append(placement.rawValue)
    }
}

if failures.isEmpty {
    print("PASS: all resize cursors matched the system frame-resize cursors.")
} else {
    fputs("FAIL: resize cursor mismatch at \(failures.joined(separator: ", ")).\n", stderr)
    exit(1)
}
