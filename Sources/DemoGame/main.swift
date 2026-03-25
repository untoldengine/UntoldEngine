//
//  main.swift
//

#if os(macOS)
    import AppKit
    import Foundation

    let executableName = URL(fileURLWithPath: CommandLine.arguments.first ?? "").lastPathComponent
    if executableName == "DemoGame" {
        fputs("[DEPRECATED] DemoGame is deprecated. Please use: swift run untoldsandbox\n", stderr)
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
#endif
