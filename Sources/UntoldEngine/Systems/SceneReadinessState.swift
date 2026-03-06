//
//  SceneReadinessState.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
