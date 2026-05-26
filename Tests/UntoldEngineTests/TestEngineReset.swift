//
//  TestEngineReset.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine

/// Resets all global engine state so that each test class starts with a clean slate.
/// Call this at the top of every XCTestCase.setUp() that creates entities or
/// touches the ECS, to prevent stale entity IDs from causing out-of-bounds crashes
/// when tests run sequentially.
@MainActor func resetEngineTestState() {
    scene = Scene()
    CameraSystem.shared.activeCamera = nil
    visibleEntityIds.removeAll()
    entityMeshMap.removeAll()
    entityNameMap.removeAll()
    reverseEntityNameMap.removeAll()
    globalEntityCounter = 0
    needsFinalizeDestroys = false
    hasPendingDestroys = false
    clearCustomSystems()
    for frame in 0 ..< 3 {
        tripleVisibleEntities.setWrite(frame: frame, with: [])
    }
    scenePickingDirtyEntities.removeAll()
    scenePickingSystemInitialized = false
    scenePickingGPUAvailable = false
    activeEntity = .invalid
    OctreeSystem.shared.clear()
    resetSceneChannelVisibility()
    setSceneReady(true)
}
