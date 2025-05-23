//
//  VisualDebugger.swift
//
//
//  Created by Harold Serrano on 5/23/25.
//

import Foundation
import Metal

struct DebugTextureEntry {
    let name: String
    let texture: MTLTexture
}

class DebugTextureRegistry {
    static var entries: [DebugTextureEntry] = []

    static func register(name: String, texture: MTLTexture) {
        entries.append(DebugTextureEntry(name: name, texture: texture))
    }

    static func get(byName name: String) -> MTLTexture? {
        return entries.first(where: { $0.name == name })?.texture
    }

    static func allNames() -> [String] {
        return entries.map { $0.name }
    }

    static func reset() {
        entries.removeAll()
    }
}
