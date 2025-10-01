//
//  VisualDebugger.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
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
        entries.first(where: { $0.name == name })?.texture
    }

    static func allNames() -> [String] {
        entries.map(\.name)
    }

    static func reset() {
        entries.removeAll()
    }
}
