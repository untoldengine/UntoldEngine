//
//  SceneReadinessState.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

private final class SceneReadinessState {
    static let shared = SceneReadinessState()

    private let lock = NSLock()
    private var ready = true

    private init() {}

    func setReady(_ isReady: Bool) {
        lock.lock()
        ready = isReady
        lock.unlock()
    }

    func isReady() -> Bool {
        lock.lock()
        let value = ready
        lock.unlock()
        return value
    }
}

/// Controls whether scene-dependent operations (like XR picking/input processing)
/// should run.
///
/// Set this to `false` while asynchronously building/mutating the scene and set
/// it back to `true` once the scene is safe for interaction.
public func setSceneReady(_ ready: Bool) {
    SceneReadinessState.shared.setReady(ready)
}

/// Returns whether the scene is marked ready for interaction.
public func isSceneReady() -> Bool {
    SceneReadinessState.shared.isReady()
}

