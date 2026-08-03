//
//  CameraNode.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Declares the scene camera. By default it wraps the renderer's game camera,
/// so declaring `CameraNode()` positions the existing active camera.
@MainActor
public final class CameraNode: Node {
    public init(entityID: EntityID? = nil, name: String? = nil) {
        super.init(entityID: entityID ?? findGameCamera(), name: name) {}

        // An explicitly passed entity may not be a camera yet. Promote it,
        // matching the light nodes, which create their component when missing.
        if !hasComponent(entityId: self.entityID, componentType: CameraComponent.self) {
            createGameCamera(entityId: self.entityID)
            if let n = name { setEntityName(entityId: self.entityID, name: n) }
        }
    }

    @discardableResult
    public func lookAt(eye: simd_float3, target: simd_float3 = .zero, up: simd_float3 = simd_float3(0, 1, 0)) -> Self {
        cameraLookAt(entityId: entityID, eye: eye, target: target, up: up)
        return self
    }
}
