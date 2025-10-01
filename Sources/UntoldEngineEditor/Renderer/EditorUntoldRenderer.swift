//
//  UntoldRenderer.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import simd
import UntoldEngine


extension UntoldRenderer
{
    func handleSceneInput() {
        // Game mode blocks editor + camera input entirely
        if gameMode { return }

        // Always allow camera WASDQE input, regardless of editor state
        let input = (
            w: InputSystem.shared.keyState.wPressed,
            a: InputSystem.shared.keyState.aPressed,
            s: InputSystem.shared.keyState.sPressed,
            d: InputSystem.shared.keyState.dPressed,
            q: InputSystem.shared.keyState.qPressed,
            e: InputSystem.shared.keyState.ePressed
        )
        moveCameraWithInput(entityId: findSceneCamera(), input: input, speed: 1, deltaTime: 0.1)

        // Editor is optional; only gate editor logic with this flag
        let isEditorEnabled = editorController?.isEnabled ?? (editorController != nil)

        // Only proceed into gizmo/editor handling if:
        //  - editor exists/enabled
        //  - there is an active entity
        //  - user intent suggests editing (Shift or gizmo is active)
        guard isEditorEnabled,
              activeEntity != .invalid,
              (InputSystem.shared.keyState.shiftPressed || gizmoActive)
        else {
            return
        }

        // From here on, we can safely touch editor-only parts
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return
        }
        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: activeEntity) else {
            handleError(.noLocalTransformComponent)
            return
        }

        // Convenience to avoid repeating the optional chaining
        @inline(__always)
        func refreshInspector() { editorController?.refreshInspector() }

        switch (editorController!.activeMode, editorController!.activeAxis) {
        // MARK: - Translate
        case (.translate, .x) where InputSystem.shared.mouseActive:
            let axis = simd_float3(1, 0, 0)
            let amt = computeAxisTranslationGizmo(
                axisWorldDir: axis,
                gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                mouseDelta: simd_float2(InputSystem.shared.mouseDeltaX, InputSystem.shared.mouseDeltaY),
                viewMatrix: cameraComponent.viewSpace,
                projectionMatrix: renderInfo.perspectiveSpace,
                viewportSize: renderInfo.viewPort
            )
            let t = axis * amt
            translateBy(entityId: activeEntity, position: t)
            translateBy(entityId: parentEntityIdGizmo, position: t)
            refreshInspector()

        case (.translate, .y) where InputSystem.shared.mouseActive:
            let axis = simd_float3(0, 1, 0)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(InputSystem.shared.mouseDeltaX, InputSystem.shared.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            let t = axis * amt
            translateBy(entityId: activeEntity, position: t)
            translateBy(entityId: parentEntityIdGizmo, position: t)
            refreshInspector()

        case (.translate, .z) where InputSystem.shared.mouseActive:
            let axis = simd_float3(0, 0, 1)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(InputSystem.shared.mouseDeltaX, InputSystem.shared.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            let t = axis * amt
            translateBy(entityId: activeEntity, position: t)
            translateBy(entityId: parentEntityIdGizmo, position: t)
            refreshInspector()

        // MARK: - Rotate
        case (.rotate, .x) where InputSystem.shared.mouseActive:
            let axis = simd_float3(1, 0, 0)
            let angle = computeRotationAngleFromGizmo(
                axis: axis,
                gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                lastMousePos: simd_float2(InputSystem.shared.lastMouseX, InputSystem.shared.lastMouseY),
                currentMousePos: simd_float2(InputSystem.shared.mouseX, InputSystem.shared.mouseY),
                viewMatrix: cameraComponent.viewSpace,
                projectionMatrix: renderInfo.perspectiveSpace,
                viewportSize: renderInfo.viewPort,
                sensitivity: 100.0
            )
            var r = getAxisRotations(entityId: activeEntity)
            r.x -= angle * 10
            applyAxisRotations(entityId: activeEntity, axis: r)
            refreshInspector()

        case (.rotate, .y) where InputSystem.shared.mouseActive:
            let axis = simd_float3(0, 1, 0)
            let angle = computeRotationAngleFromGizmo(
                axis: axis,
                gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                lastMousePos: simd_float2(InputSystem.shared.lastMouseX, InputSystem.shared.lastMouseY),
                currentMousePos: simd_float2(InputSystem.shared.mouseX, InputSystem.shared.mouseY),
                viewMatrix: cameraComponent.viewSpace,
                projectionMatrix: renderInfo.perspectiveSpace,
                viewportSize: renderInfo.viewPort,
                sensitivity: 100.0
            )
            var r = getAxisRotations(entityId: activeEntity)
            r.y += angle * 10
            applyAxisRotations(entityId: activeEntity, axis: r)
            refreshInspector()

        case (.rotate, .z) where InputSystem.shared.mouseActive:
            let axis = simd_float3(0, 0, 1)
            let angle = computeRotationAngleFromGizmo(
                axis: axis,
                gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                lastMousePos: simd_float2(InputSystem.shared.lastMouseX, InputSystem.shared.lastMouseY),
                currentMousePos: simd_float2(InputSystem.shared.mouseX, InputSystem.shared.mouseY),
                viewMatrix: cameraComponent.viewSpace,
                projectionMatrix: renderInfo.perspectiveSpace,
                viewportSize: renderInfo.viewPort,
                sensitivity: 100.0
            )
            var r = getAxisRotations(entityId: activeEntity)
            r.z += angle * 10
            applyAxisRotations(entityId: activeEntity, axis: r)
            refreshInspector()

        // MARK: - Scale
        case (.scale, .x) where InputSystem.shared.mouseActive:
            let axis = simd_float3(1, 0, 0)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(InputSystem.shared.mouseDeltaX, InputSystem.shared.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
                handleLightScaleInput(projectedAmount: amt, axis: axis)
            } else {
                applyWorldSpaceScaleDelta(entityId: activeEntity, worldAxis: axis, projectedAmount: amt)
            }
            refreshInspector()

        case (.scale, .y) where InputSystem.shared.mouseActive:
            let axis = simd_float3(0, 1, 0)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(InputSystem.shared.mouseDeltaX, InputSystem.shared.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
                handleLightScaleInput(projectedAmount: amt, axis: axis)
            } else {
                applyWorldSpaceScaleDelta(entityId: activeEntity, worldAxis: axis, projectedAmount: amt)
            }
            refreshInspector()

        case (.scale, .z) where InputSystem.shared.mouseActive:
            let axis = simd_float3(0, 0, 1)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(InputSystem.shared.mouseDeltaX, InputSystem.shared.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
                handleLightScaleInput(projectedAmount: amt, axis: axis)
            } else {
                applyWorldSpaceScaleDelta(entityId: activeEntity, worldAxis: axis, projectedAmount: amt)
            }
            refreshInspector()

        // MARK: - Light direction (view-plane drag)
        case (.lightRotate, .none) where InputSystem.shared.mouseActive:
            let lightDirEntity = findEntity(name: "directionHandle")

            // Choose 2D plane aligned to camera forward
            let cameraForward = -cameraComponent.zAxis
            let absF = simd_abs(cameraForward)
            let (axis1, axis2): (simd_float3, simd_float3) = {
                if absF.x > absF.y && absF.x > absF.z { return (simd_float3(0,1,0), simd_float3(0,0,1)) } // YZ
                if absF.y > absF.x && absF.y > absF.z { return (simd_float3(1,0,0), simd_float3(0,0,1)) } // XZ
                return (simd_float3(1,0,0), simd_float3(0,1,0))                                          // XY
            }()

            let p1 = computeAxisTranslationGizmo(axisWorldDir: axis1,
                                                 gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                 mouseDelta: simd_float2(InputSystem.shared.mouseDeltaX, InputSystem.shared.mouseDeltaY),
                                                 viewMatrix: cameraComponent.viewSpace,
                                                 projectionMatrix: renderInfo.perspectiveSpace,
                                                 viewportSize: renderInfo.viewPort)

            let p2 = computeAxisTranslationGizmo(axisWorldDir: axis2,
                                                 gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                 mouseDelta: simd_float2(InputSystem.shared.mouseDeltaX, InputSystem.shared.mouseDeltaY),
                                                 viewMatrix: cameraComponent.viewSpace,
                                                 projectionMatrix: renderInfo.perspectiveSpace,
                                                 viewportSize: renderInfo.viewPort)

            let t = axis1 * p1 + axis2 * p2
            translateBy(entityId: lightDirEntity!, position: t)

            let lightPos = getPosition(entityId: parentEntityIdGizmo)
            let gizmoPos = getPosition(entityId: lightDirEntity!)
            let zAxis = simd_normalize(gizmoPos - lightPos) * -1.0

            let worldUp = simd_float3(0, 1, 0)
            var xAxis = simd_normalize(simd_cross(worldUp, zAxis))
            if simd_length(xAxis) < 0.001 {
                xAxis = simd_normalize(simd_cross(simd_float3(1, 0, 0), zAxis))
            }
            let yAxis = simd_normalize(simd_cross(zAxis, xAxis))
            let rotM = simd_float3x3(columns: (xAxis, yAxis, zAxis))
            localTransformComponent.rotation = transformMatrix3nToQuaternion(m: rotM)

        default:
            break
        }
    }
}
