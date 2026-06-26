//
//  main.swift
//  LargeSceneStreamingDemo
//

#if os(macOS)
    import AppKit

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
#endif
