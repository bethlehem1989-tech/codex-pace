import AppKit
import SwiftUI

final class DraggableTabHostingView<Content: View>: NSHostingView<Content> {
    var onClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onContextMenu: ((NSEvent) -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var onDragStarted: (() -> Void)?
    var onMove: ((NSPoint) -> Void)?
    var onMoveEnded: (() -> Void)?
    var onOpacityDelta: ((CGFloat) -> Void)?

    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .enabledDuringMouseDrag, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseMoved(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            onContextMenu?(event)
            return
        }

        if event.clickCount >= 2 {
            onDoubleClick?()
            return
        }

        guard let window else { return }

        var startMouse = NSEvent.mouseLocation
        var startOrigin = window.frame.origin
        var didDrag = false

        while true {
            guard let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else {
                continue
            }

            switch nextEvent.type {
            case .leftMouseDragged:
                let currentMouse = NSEvent.mouseLocation
                let delta = NSPoint(
                    x: currentMouse.x - startMouse.x,
                    y: currentMouse.y - startMouse.y
                )
                if !didDrag, hypot(delta.x, delta.y) > 3 {
                    didDrag = true
                    onDragStarted?()
                    let collapsedOrigin = window.frame.origin
                    onMove?(
                        NSPoint(
                            x: collapsedOrigin.x + delta.x,
                            y: collapsedOrigin.y + delta.y
                        )
                    )
                    startMouse = currentMouse
                    startOrigin = window.frame.origin
                    continue
                }
                if didDrag {
                    onMove?(NSPoint(x: startOrigin.x + delta.x, y: startOrigin.y + delta.y))
                }
            case .leftMouseUp:
                if didDrag {
                    onMoveEnded?()
                } else {
                    onClick?()
                }
                return
            default:
                break
            }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onContextMenu?(event)
    }

    override func scrollWheel(with event: NSEvent) {
        let deltaY = event.scrollingDeltaY
        guard deltaY != 0 else {
            super.scrollWheel(with: event)
            return
        }
        onOpacityDelta?(deltaY)
    }
}
