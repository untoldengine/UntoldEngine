//
//  main.swift
//

#if os(macOS)
    import AppKit
    import Foundation

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
#endif
