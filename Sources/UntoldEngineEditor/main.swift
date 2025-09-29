//
//  main.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 14/9/25.
//

import AppKit
import SwiftUI
import MetalKit
import UntoldEngine


// AppDelegate: Boiler plate code
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_: Notification) {
        print("Launching Untold Engine Editor v0.2")

        // Step 1. Create and configure the window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Untold Engine Editor v0.2"
        window.center()            
        
        let hostingView = NSHostingView(rootView: EditorView())
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}

// Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

app.run()

