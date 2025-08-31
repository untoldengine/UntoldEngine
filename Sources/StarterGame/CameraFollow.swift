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

public class CameraFollowComponent: Component, Codable {
    var targetName: String = "nil"
    var offset: simd_float3 = .zero
    public required init() {}
}

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

public func cameraFollowUpdate(deltaTime _: Float) {
    let customId = getComponentId(for: CameraFollowComponent.self)
    let entities = queryEntitiesWithComponentIds([customId], in: scene)

    for entity in entities {
        guard let cameraFollowComponent = scene.get(component: CameraFollowComponent.self, for: entity) else { continue }

        cameraFollow(entityId: entity, targetName: cameraFollowComponent.targetName, offset: cameraFollowComponent.offset, smoothSpeed: 0.5, alignWithOrientation: false)
    }
}

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
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    guard let targetId: EntityID = findEntity(name: targetName) else {
        return
    }

    // Get the target's position and orientation
    var targetPosition: simd_float3 = UntoldEngine.getPosition(entityId: targetId)
    let targetOrientation: simd_float3x3 = UntoldEngine.getOrientation(entityId: targetId) // Rotation matrix

    var cameraPosition = cameraComponent.localPosition

    // Apply axis locking to the target position
    if lockXAxis { targetPosition.x = cameraPosition.x }
    if lockYAxis { targetPosition.y = cameraPosition.y }
    if lockZAxis { targetPosition.z = cameraPosition.z }

    // Calculate the offset relative to the entity's orientation
    var adjustedOffset = offset
    if alignWithOrientation {
        // Rotate the offset vector using the 3x3 rotation matrix
        adjustedOffset = targetOrientation * offset
    }

    // Calculate the desired position by applying the adjusted offset
    let desiredPosition: simd_float3 = targetPosition + adjustedOffset

    // Smoothly interpolate the camera position towards the desired position
    cameraPosition = lerp(start: cameraPosition, end: desiredPosition, t: smoothSpeed)

    // Move the camera to the new position
    moveCameraTo(entityId: entityId, cameraPosition.x, cameraPosition.y, cameraPosition.z)

    // Align the camera's view direction using lookAt
    if alignWithOrientation {
        // Calculate the forward direction of the entity
        let _: simd_float3 = targetOrientation * simd_float3(0, 0, 1) // Forward direction in local space

        // Determine the "up" vector (you might need to adjust this based on your engine's coordinate system)
        let up: simd_float3 = targetOrientation * simd_float3(0, 1, 0) // Transform the local up vector by the orientation

        // Use lookAt to orient the camera towards the target's forward direction
        cameraLookAt(entityId: entityId, eye: cameraPosition, target: targetPosition, up: up)
    }
}

var CameraFollowComponent_Editor: ComponentOption_Editor = .init(
    id: getComponentId(for: CameraFollowComponent.self),
    name: "Camera Follow",
    type: CameraFollowComponent.self,
    view: makeEditorView(fields: [
        .text(label: "Target Name",
              placeholder: "Entity name",
              get: { entityId in
                  getTargetName(entityId: entityId) ?? "None"
              },
              set: { entityId, targetName in
                  setTargetName(entityId: entityId, name: targetName)
              }),

        .vector3(label: "Offset",
                 get: { entityId in
                     getOffsetTarget(entityId: entityId)
                 },
                 set: { entityId, newOffset in
                     setOffsetTarget(entityId: entityId, offset: newOffset)
                 }),

    ]),
    onAdd: { entityId in
        registerComponent(entityId: entityId, componentType: CameraFollowComponent.self)
    }
)
