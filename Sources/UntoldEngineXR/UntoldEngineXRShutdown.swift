//
//  UntoldEngineXRShutdown.swift
//  UntoldEngineXR
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if os(visionOS)
    import Foundation
    import UntoldEngine

    /// Resets UntoldEngine world state for XR while keeping the XR runtime alive.
    /// Use this when unloading one scene/asset and preparing to load another
    /// within the same immersive session.
    public func resetUntoldWorldForXR(completion: (() -> Void)? = nil) {
        setSceneReady(false)
        InputSystem.shared.unregisterXREvents()
        RealSurfacePlaneStore.shared.clear()
        USCSystem.shared.stopPlayMode()
        let wasStreamingEnabled = GeometryStreamingSystem.shared.enabled
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.reset()
        SystemEventBus.shared.clearPendingEvents()

        destroyAllEntities {
            GeometryStreamingSystem.shared.reset()
            clearSceneBatches()
            OctreeSystem.shared.clear()
            MemoryBudgetManager.shared.clear()
            shutdownScenePickingSystem()
            CameraSystem.shared.activeCamera = nil
            clearScriptRegistry()
            GeometryStreamingSystem.shared.enabled = wasStreamingEnabled
            completion?()
        }
    }

    /// Performs full XR shutdown: reset world state, clear spatial input, then stop XR.
    /// Caller should release app-side XR references (for example, `XRHolder.shared.xr = nil`)
    /// inside `completion`.
    public func shutdownUntoldEngineXR(_ xr: UntoldEngineXR, completion: (() -> Void)? = nil) {
        resetUntoldWorldForXR {
            xr.clearSpatialInput()
            xr.stop()
            completion?()
        }
    }
#endif
