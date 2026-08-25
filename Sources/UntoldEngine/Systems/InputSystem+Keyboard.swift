//
//  InputSystem+Keyboard.swift
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

public struct KeyState {
    public var wPressed = false, aPressed = false, sPressed = false, dPressed = false
    public var hPressed = false, tabPressed = false, fPressed = false
    public var f1Pressed = false, f2Pressed = false, f3Pressed = false, f4Pressed = false
    public var f5Pressed = false, f6Pressed = false, f7Pressed = false, f8Pressed = false
    public var f9Pressed = false, f10Pressed = false, f11Pressed = false, f12Pressed = false
    public var jPressed = false, kPressed = false, lPressed = false
    public var qPressed = false, ePressed = false
    public var spacePressed = false, shiftPressed = false, ctrlPressed = false
    public var altPressed = false, commandPressed = false
    public var leftMousePressed = false, rightMousePressed = false, middleMousePressed = false
}

public extension InputSystem {
    #if !os(macOS)
        func registerKeyboardEvents() {}
        func unregisterKeyboardEvents() {}
    #else
        func registerKeyboardEvents() {
            guard keyboardEventMonitorTokens.isEmpty else { return }
            registerTextInputFocusObservers()

            let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handleFlagsChanged(event)
                return event
            }
            if let flagsMonitor {
                keyboardEventMonitorTokens.append(flagsMonitor)
            }

            let keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if self?.shouldHandleKey(event) == true {
                    self?.keyPressed(event.keyCode)
                    return nil // Mark event as handled
                }
                return event // Pass event to the system
            }
            if let keyDownMonitor {
                keyboardEventMonitorTokens.append(keyDownMonitor)
            }

            let keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
                if self?.shouldHandleKey(event) == true {
                    self?.keyReleased(event.keyCode)
                    return nil // Mark event as handled
                }
                return event
            }
            if let keyUpMonitor {
                keyboardEventMonitorTokens.append(keyUpMonitor)
            }
        }

        func unregisterKeyboardEvents() {
            for token in keyboardEventMonitorTokens {
                NSEvent.removeMonitor(token)
            }
            keyboardEventMonitorTokens.removeAll()

            for token in textInputObserverTokens {
                NotificationCenter.default.removeObserver(token)
            }
            textInputObserverTokens.removeAll()
            isTextInputFocused = false
        }

        private func registerTextInputFocusObservers() {
            guard textInputObserverTokens.isEmpty else { return }

            let begin = NotificationCenter.default.addObserver(
                forName: NSText.didBeginEditingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isTextInputFocused = true
            }

            let end = NotificationCenter.default.addObserver(
                forName: NSText.didEndEditingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isTextInputFocused = false
            }

            let resign = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.isTextInputFocused = false
            }

            textInputObserverTokens.append(begin)
            textInputObserverTokens.append(end)
            textInputObserverTokens.append(resign)
        }

        private func handleFlagsChanged(_ event: NSEvent) {
            // Shift key
            if event.modifierFlags.contains(.shift) {
                keyState.shiftPressed = true
            } else {
                keyState.shiftPressed = false
            }

            // Control key
            if event.modifierFlags.contains(.control) {
                keyState.ctrlPressed = true
            } else {
                keyState.ctrlPressed = false
            }

            // Command key
            if event.modifierFlags.contains(.command) {
                keyState.commandPressed = true
            } else {
                keyState.commandPressed = false
            }
        }

        private func shouldHandleKey(_: NSEvent) -> Bool {
            !isTextInputFocused
        }

        private var hKeyCode: UInt16 {
            4
        }

        private var tabKeyCode: UInt16 {
            48
        }

        private var fKeyCode: UInt16 {
            3
        }

        private var f1KeyCode: UInt16 {
            122
        }

        private var f2KeyCode: UInt16 {
            120
        }

        private var f3KeyCode: UInt16 {
            99
        }

        private var f4KeyCode: UInt16 {
            118
        }

        private var f5KeyCode: UInt16 {
            96
        }

        private var f6KeyCode: UInt16 {
            97
        }

        private var f7KeyCode: UInt16 {
            98
        }

        private var f8KeyCode: UInt16 {
            100
        }

        private var f9KeyCode: UInt16 {
            101
        }

        private var f10KeyCode: UInt16 {
            109
        }

        private var f11KeyCode: UInt16 {
            103
        }

        private var f12KeyCode: UInt16 {
            111
        }

        func keyPressed(_ keyCode: UInt16) {
            switch keyCode {
            case kVK_ANSI_A: keyState.aPressed = true
            case kVK_ANSI_W: keyState.wPressed = true
            case kVK_ANSI_D: keyState.dPressed = true
            case kVK_ANSI_S: keyState.sPressed = true
            case kVK_ANSI_Q: keyState.qPressed = true
            case kVK_ANSI_E: keyState.ePressed = true
            case hKeyCode: keyState.hPressed = true
            case tabKeyCode: keyState.tabPressed = true
            case fKeyCode: keyState.fPressed = true
            case f1KeyCode: keyState.f1Pressed = true
            case f2KeyCode: keyState.f2Pressed = true
            case f3KeyCode: keyState.f3Pressed = true
            case f4KeyCode: keyState.f4Pressed = true
            case f5KeyCode: keyState.f5Pressed = true
            case f6KeyCode: keyState.f6Pressed = true
            case f7KeyCode: keyState.f7Pressed = true
            case f8KeyCode: keyState.f8Pressed = true
            case f9KeyCode: keyState.f9Pressed = true
            case f10KeyCode: keyState.f10Pressed = true
            case f11KeyCode: keyState.f11Pressed = true
            case f12KeyCode: keyState.f12Pressed = true
            case kVK_ANSI_Space: keyState.spacePressed = true
            case kVK_ANSI_J: keyState.jPressed = true
            case kVK_ANSI_K: keyState.kPressed = true
            case kVK_ANSI_L: keyState.lPressed = true
            // case kVK_ANSI_G: print("G pressed")
            default: break
            }

            delegate?.didUpdateKeyState()
        }

        func keyReleased(_ keyCode: UInt16) {
            switch keyCode {
            case kVK_ANSI_A: keyState.aPressed = false
            case kVK_ANSI_W: keyState.wPressed = false
            case kVK_ANSI_D: keyState.dPressed = false
            case kVK_ANSI_S: keyState.sPressed = false
            case kVK_ANSI_Q: keyState.qPressed = false
            case kVK_ANSI_E: keyState.ePressed = false
            case hKeyCode: keyState.hPressed = false
            case tabKeyCode: keyState.tabPressed = false
            case fKeyCode: keyState.fPressed = false
            case f1KeyCode: keyState.f1Pressed = false
            case f2KeyCode: keyState.f2Pressed = false
            case f3KeyCode: keyState.f3Pressed = false
            case f4KeyCode: keyState.f4Pressed = false
            case f5KeyCode: keyState.f5Pressed = false
            case f6KeyCode: keyState.f6Pressed = false
            case f7KeyCode: keyState.f7Pressed = false
            case f8KeyCode: keyState.f8Pressed = false
            case f9KeyCode: keyState.f9Pressed = false
            case f10KeyCode: keyState.f10Pressed = false
            case f11KeyCode: keyState.f11Pressed = false
            case f12KeyCode: keyState.f12Pressed = false
            case kVK_ANSI_J: keyState.jPressed = false
            case kVK_ANSI_K: keyState.kPressed = false
            case kVK_ANSI_L: keyState.lPressed = false
            case kVK_ANSI_Space: keyState.spacePressed = false
            // case kVK_ANSI_G: print("G released")
            default: break
            }

            delegate?.didUpdateKeyState()
        }
    #endif
}
