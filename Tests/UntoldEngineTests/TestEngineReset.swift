//
//  TestEngineReset.swift
//  UntoldEngineTests
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

@testable import UntoldEngine

/// Resets all global engine state so that each test class starts with a clean slate.
/// Call this at the top of every XCTestCase.setUp() that creates entities or
/// touches the ECS, to prevent stale entity IDs from causing out-of-bounds crashes
/// when tests run sequentially.
func resetEngineTestState() {
    scene = Scene()
    CameraSystem.shared.activeCamera = nil
    visibleEntityIds.removeAll()
    entityMeshMap.removeAll()
    entityNameMap.removeAll()
    reverseEntityNameMap.removeAll()
    globalEntityCounter = 0
    needsFinalizeDestroys = false
    hasPendingDestroys = false
    customSystems.removeAll()
    scenePickingDirtyEntities.removeAll()
    scenePickingSystemInitialized = false
    scenePickingGPUAvailable = false
    activeEntity = .invalid
    OctreeSystem.shared.clear()
}
