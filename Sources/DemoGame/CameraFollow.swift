//
//  CameraFollow.swift
//
//
//  Created by Harold Serrano on 5/11/25.
//

import Foundation
import simd
import SwiftUI
import UntoldEngine

// CameraFollowComponent defines how a camera should follow a target entity.
// It stores the name of the target and the offset from that target.
// This makes it possible to create a third-person or top-down camera easily.
public class CameraFollowComponent: Component, Codable {
    var targetName: String = "nil"      // The name of the entity the camera should follow
    var offset: simd_float3 = .zero     // The offset position relative to the target
    public required init() {}
}

// -----------------------------------------------------------------------------
// Helper functions for accessing and modifying CameraFollowComponent values
// -----------------------------------------------------------------------------

func getOffsetTarget(entityId: EntityID) -> simd_float3 {
    guard let cameraFollowComponent = scene.get(component: CameraFollowComponent.self, for: entityId) else { return .zero }
    return cameraFollowComponent.offset
}

func setOffsetTarget(entityId: EntityID, offset: simd_float3) {
    guard let cameraFollowComponent = scene.get(component: CameraFollowComponent.self, for: entityId) else { return }
    cameraFollowComponent.offset = offset
}

func getTargetName(entityId: EntityID) -> String? {
    guard let cameraFollowComponent = scene.get(component: CameraFollowComponent.self, for: entityId) else { return nil }
    return cameraFollowComponent.targetName
}

func setTargetName(entityId: EntityID, name: String) {
    guard let cameraFollowComponent = scene.get(component: CameraFollowComponent.self, for: entityId) else { return }
    cameraFollowComponent.targetName = name
}

// -----------------------------------------------------------------------------
// Camera Follow System
// Updates all entities with a CameraFollowComponent once per frame.
// Calls the cameraFollow function to smoothly track the target entity.
// -----------------------------------------------------------------------------

public func cameraFollowUpdate(deltaTime _: Float) {
    let customId = getComponentId(for: CameraFollowComponent.self)
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    for entity in entities {
        guard let cameraFollowComponent = scene.get(component: CameraFollowComponent.self, for: entity) else { continue }

        cameraFollow(
            entityId: entity,
            targetName: cameraFollowComponent.targetName,
            offset: cameraFollowComponent.offset,
            smoothSpeed: 0.5,
            alignWithOrientation: false
        )
    }
}

// -----------------------------------------------------------------------------
// Core camera follow logic
// Moves the camera smoothly to follow the target and optionally aligns its
// orientation with the target’s forward direction.
// -----------------------------------------------------------------------------

func cameraFollow(
    entityId: EntityID,
    targetName: String,
    offset: simd_float3,
    smoothSpeed: Float,
    lockXAxis: Bool = false,
    lockYAxis: Bool = false,
    lockZAxis: Bool = false,
    alignWithOrientation: Bool = true
) {
    // Ensure the entity has a CameraComponent
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    // Find the target entity by name
    guard let targetId: EntityID = findEntity(name: targetName) else {
        return
    }

    // Get the target's position and orientation
    var targetPosition: simd_float3 = UntoldEngine.getPosition(entityId: targetId)
    let targetOrientation: simd_float3x3 = UntoldEngine.getOrientation(entityId: targetId) // Rotation matrix
    var cameraPosition = cameraComponent.localPosition

    // Apply axis locking (keeps the camera fixed on chosen axes)
    if lockXAxis { targetPosition.x = cameraPosition.x }
    if lockYAxis { targetPosition.y = cameraPosition.y }
    if lockZAxis { targetPosition.z = cameraPosition.z }

    // Adjust offset based on orientation if requested
    var adjustedOffset = offset
    if alignWithOrientation {
        // Rotate the offset by the target's orientation matrix
        adjustedOffset = targetOrientation * offset
    }

    // Calculate where the camera *wants* to be
    let desiredPosition: simd_float3 = targetPosition + adjustedOffset

    // Smoothly interpolate from the current camera position to the desired position
    cameraPosition = lerp(start: cameraPosition, end: desiredPosition, t: smoothSpeed)

    // Move the camera to its new position
    moveCameraTo(entityId: entityId, cameraPosition.x, cameraPosition.y, cameraPosition.z)

    // Orient the camera towards the target if enabled
    if alignWithOrientation {
        // Forward direction of the target
        let _: simd_float3 = targetOrientation * simd_float3(0, 0, 1)

        // Up vector (adjust depending on coordinate system)
        let up: simd_float3 = targetOrientation * simd_float3(0, 1, 0)

        // Look at the target from the camera’s position
        cameraLookAt(entityId: entityId, eye: cameraPosition, target: targetPosition, up: up)
    }
}

// -----------------------------------------------------------------------------
// Editor Integration
// Makes CameraFollowComponent visible in the Editor (Inspector panel).
// -----------------------------------------------------------------------------

var CameraFollowComponent_Editor: ComponentOption_Editor = .init(
    id: getComponentId(for: CameraFollowComponent.self),
    name: "Camera Follow",
    type: CameraFollowComponent.self,
    view: makeEditorView(fields: [
        // Editable field for selecting the target entity by name
        .text(label: "Target Name",
              placeholder: "Entity name",
              get: { entityId in getTargetName(entityId: entityId) ?? "None" },
              set: { entityId, targetName in setTargetName(entityId: entityId, name: targetName) }),

        // Editable field for the follow offset
        .vector3(label: "Offset",
                 get: { entityId in getOffsetTarget(entityId: entityId) },
                 set: { entityId, newOffset in setOffsetTarget(entityId: entityId, offset: newOffset) }),
    ]),
    onAdd: { entityId in
        // When added in the Editor, register this component with the entity
        registerComponent(entityId: entityId, componentType: CameraFollowComponent.self)
    }
)
