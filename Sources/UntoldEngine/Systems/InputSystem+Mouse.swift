//
//  InputSystem+Mouse.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if os(macOS)
    import AppKit
#endif

public extension InputSystem {
    #if !os(macOS)
        func registerMouseEvents() {}
        func unregisterMouseEvents() {}
    #else
        func registerMouseEvents() {
            // Left mouse button
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handleLeftMouseDown(event)
                return event
            }

            NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                self?.handleLeftMouseUp(event)
                return event
            }

            NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
                self?.handleMouseDragged(event)
                return event
            }

            // Right mouse button
            NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                self?.handleRightMouseDown(event)
                return event
            }

            NSEvent.addLocalMonitorForEvents(matching: .rightMouseUp) { [weak self] event in
                self?.handleRightMouseUp(event)
                return event
            }

            NSEvent.addLocalMonitorForEvents(matching: .rightMouseDragged) { [weak self] event in
                self?.handleMouseDragged(event)
                return event
            }

            // Middle mouse button (optional)
            NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
                self?.handleMiddleMouseDown(event)
                return event
            }

            NSEvent.addLocalMonitorForEvents(matching: .otherMouseUp) { [weak self] event in
                self?.handleMiddleMouseUp(event)
                return event
            }

            // Mouse movement
            NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                self?.handleMouseMoved(event)
                return event
            }

            // Scroll wheel
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handleScrollWheel(event)
                return event
            }
        }

        // MARK: - Mouse Button Handlers

        private func handleLeftMouseDown(_ event: NSEvent) {
            keyState.leftMousePressed = true
            mouseActive = true

            let location = event.locationInWindow
            lastMouseX = Float(location.x)
            lastMouseY = Float(location.y)
            mouseX = lastMouseX
            mouseY = lastMouseY
        }

        private func handleLeftMouseUp(_: NSEvent) {
            keyState.leftMousePressed = false
            mouseActive = false
            mouseDeltaX = 0
            mouseDeltaY = 0
        }

        private func handleRightMouseDown(_ event: NSEvent) {
            keyState.rightMousePressed = true
            mouseActive = true

            let location = event.locationInWindow
            lastMouseX = Float(location.x)
            lastMouseY = Float(location.y)
            mouseX = lastMouseX
            mouseY = lastMouseY
        }

        private func handleRightMouseUp(_: NSEvent) {
            keyState.rightMousePressed = false
            mouseActive = false
            mouseDeltaX = 0
            mouseDeltaY = 0
        }

        private func handleMiddleMouseDown(_ event: NSEvent) {
            if event.buttonNumber == 2 { // Middle button
                keyState.middleMousePressed = true
            }
        }

        private func handleMiddleMouseUp(_ event: NSEvent) {
            if event.buttonNumber == 2 { // Middle button
                keyState.middleMousePressed = false
            }
        }

        // MARK: - Mouse Movement Handlers

        private func handleMouseMoved(_ event: NSEvent) {
            let location = event.locationInWindow
            lastMouseX = mouseX
            lastMouseY = mouseY
            mouseX = Float(location.x)
            mouseY = Float(location.y)

            mouseDeltaX = mouseX - lastMouseX
            mouseDeltaY = mouseY - lastMouseY
        }

        private func handleMouseDragged(_ event: NSEvent) {
            let location = event.locationInWindow
            lastMouseX = mouseX
            lastMouseY = mouseY
            mouseX = Float(location.x)
            mouseY = Float(location.y)

            // event.deltaX/Y gives device-independent per-event movement, avoiding
            // the large position jumps that trackpad fast-swipes produce.
            mouseDeltaX = Float(event.deltaX)
            mouseDeltaY = Float(event.deltaY)
        }

        private func handleScrollWheel(_ event: NSEvent) {
            // Scale trackpad (hasPreciseScrollingDeltas) to mouse-wheel magnitude so
            // a two-finger drag orbits at a comparable speed to right-click drag.
            let scale: Float = event.hasPreciseScrollingDeltas ? 0.2 : 1.0
            scrollDelta.x = Float(event.scrollingDeltaX) * scale
            scrollDelta.y = Float(event.scrollingDeltaY) * scale
        }
    #endif
}
