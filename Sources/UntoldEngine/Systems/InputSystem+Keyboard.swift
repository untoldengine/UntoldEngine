//
//  InputSystem+Keyboard.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#if os(macOS)
import AppKit
#endif

public struct KeyState {
    public var wPressed = false, aPressed = false, sPressed = false, dPressed = false
    public var qPressed = false, ePressed = false
    public var spacePressed = false, shiftPressed = false, ctrlPressed = false
    public var altPressed = false
    public var leftMousePressed = false, rightMousePressed = false, middleMousePressed = false
}

extension InputSystem
{
#if !os(macOS)
    public func registerKeyboardEvents() { }
    public func unregisterKeyboardEvents() { }
#else
    public func registerKeyboardEvents() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.shouldHandleKey(event) == true {
                self?.keyPressed(event.keyCode)
                return nil // Mark event as handled
            }
            return event // Pass event to the system
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if self?.shouldHandleKey(event) == true {
                self?.keyReleased(event.keyCode)
                return nil // Mark event as handled
            }
            return event
        }
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
    }
    
    private func shouldHandleKey(_: NSEvent) -> Bool {
        if let firstResponder = NSApp.keyWindow?.firstResponder {
            if firstResponder is NSTextView {
                return false // allow normal text input
            }
        }
        
        return true // handle the key event
    }
        
    func keyPressed(_ keyCode: UInt16) {
        switch keyCode {
        case kVK_ANSI_A: keyState.aPressed   = true
        case kVK_ANSI_W: keyState.wPressed   = true
        case kVK_ANSI_D: keyState.dPressed   = true
        case kVK_ANSI_S: keyState.sPressed   = true
        case kVK_ANSI_Q: keyState.qPressed   = true
        case kVK_ANSI_E: keyState.ePressed   = true
        case kVK_ANSI_Space: keyState.spacePressed = true
        //case kVK_ANSI_G: print("G pressed")
        default: break
        }
        
        delegate?.didUpdateKeyState( )
    }
    
    func keyReleased(_ keyCode: UInt16) {
        switch keyCode {
        case kVK_ANSI_A: keyState.aPressed   = false
        case kVK_ANSI_W: keyState.wPressed   = false
        case kVK_ANSI_D: keyState.dPressed   = false
        case kVK_ANSI_S: keyState.sPressed   = false
        case kVK_ANSI_Q: keyState.qPressed   = false
        case kVK_ANSI_E: keyState.ePressed   = false
        case kVK_ANSI_Space: keyState.spacePressed = false
        //case kVK_ANSI_G: print("G released")
        default: break
        }
        
        delegate?.didUpdateKeyState( )
    }
#endif
}
