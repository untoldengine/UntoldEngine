//
//  InputSystem+XR.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import simd

#if os(visionOS)
    import ARKit
    import RealityKit
    import SwiftUI
#endif

public struct SpatialInputState {
    public var primaryTapActive = false
    public var primaryDragActive = false
    public var secondaryTapActive = false
    public var handTrackingActive = false

    public var leftHandPosition: simd_float3 = .zero
    public var rightHandPosition: simd_float3 = .zero
    public var leftHandPinching = false
    public var rightHandPinching = false

    public var gazePosition: simd_float3 = .zero
    public var gazeDirection: simd_float3 = .zero
}

public extension InputSystem {
    #if !os(visionOS)
        func registerXREvents(view _: Any) {}
        func unregisterXREvents() {}
        func updateHandTracking(session _: Any) {}
    #else
        private static var spatialInputState = SpatialInputState()

        var xrInputState: SpatialInputState {
            get { Self.spatialInputState }
            set { Self.spatialInputState = newValue }
        }

        func registerXREvents(view: some View) -> some View {
            view
                .gesture(createSpatialTapGesture())
                .gesture(createSpatialDragGesture())
                .gesture(createSpatialMagnifyGesture())
        }

        // MARK: - Spatial Tap Gesture (Primary Selection)

        private func createSpatialTapGesture() -> some Gesture {
            SpatialTapGesture(count: 1, coordinateSpace: .local)
                .onEnded { value in
                    // Convert CGPoint to simd_float3
                    let location3D = simd_float3(Float(value.location.x), Float(value.location.y), 0.0)
                    self.handleSpatialTap(at: location3D)
                }
        }

        private func handleSpatialTap(at location: simd_float3) {
            xrInputState.primaryTapActive = true

            // Update mouse-equivalent position for compatibility
            mouseX = location.x
            mouseY = location.y

            // Simulate tap
            keyState.leftMousePressed = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.keyState.leftMousePressed = false
                self?.xrInputState.primaryTapActive = false
            }
        }

        // MARK: - Spatial Drag Gesture (Camera Orbit/Pan)

        private func createSpatialDragGesture() -> some Gesture {
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { value in
                    self.handleSpatialDragChanged(value)
                }
                .onEnded { value in
                    self.handleSpatialDragEnded(value)
                }
        }

        private func handleSpatialDragChanged(_ value: DragGesture.Value) {
            if !xrInputState.primaryDragActive {
                xrInputState.primaryDragActive = true
                cameraControlMode = .orbiting
                initialPanLocation = CGPoint(x: CGFloat(value.location.x), y: CGFloat(value.location.y))
            }

            // Update deltas for camera control
            let translation = value.translation
            panDelta.x = Float(translation.width)
            panDelta.y = Float(translation.height)

            mouseDeltaX = Float(translation.width)
            mouseDeltaY = Float(translation.height)
        }

        private func handleSpatialDragEnded(_: DragGesture.Value) {
            xrInputState.primaryDragActive = false
            cameraControlMode = .idle
            panDelta = .init(0, 0)
            mouseDeltaX = 0
            mouseDeltaY = 0
        }

        // MARK: - Spatial Magnify Gesture (Pinch to Zoom)

        private func createSpatialMagnifyGesture() -> some Gesture {
            MagnifyGesture(minimumScaleDelta: 0.0)
                .onChanged { value in
                    self.handleMagnifyChanged(value)
                }
                .onEnded { value in
                    self.handleMagnifyEnded(value)
                }
        }

        private func handleMagnifyChanged(_ value: MagnifyGesture.Value) {
            currentPinchGestureState = .changed

            let currentScale = CGFloat(value.magnification)
            let scaleDelta = currentScale - previousScale

            pinchDelta.z = Float(scaleDelta)
            previousScale = currentScale
        }

        private func handleMagnifyEnded(_: MagnifyGesture.Value) {
            currentPinchGestureState = .ended
            pinchDelta = .init(0, 0, 0)
            previousScale = 1.0
        }

        // MARK: - Hand Tracking (Advanced Input)

        func updateHandTracking(session _: ARKitSession) {
            // TODO: Implement hand tracking using visionOS 2.0 ARKit APIs
            // The ARKitSession API has changed in visionOS 2.0
            // Need to use HandTrackingProvider and HandAnchor for proper implementation

            xrInputState.handTrackingActive = false

            // Note: This is a placeholder for future implementation
            // In a real implementation, you'd:
            // 1. Request hand tracking authorization
            // 2. Query HandTrackingProvider for hand anchors
            // 3. Extract joint positions and gestures from HandAnchor
            // 4. Update xrInputState with hand positions and pinch states
        }

        // MARK: - Eye Tracking (Gaze Input)

        func updateGazeTracking(anchor: AnchorEntity?) {
            guard let anchor else { return }

            // Extract gaze position and direction from anchor
            let transform = anchor.transform
            xrInputState.gazePosition = simd_float3(
                transform.translation.x,
                transform.translation.y,
                transform.translation.z
            )

            // Forward direction from transform
            let forward = transform.matrix.columns.2
            xrInputState.gazeDirection = simd_normalize(simd_float3(
                forward.x,
                forward.y,
                forward.z
            ))
        }

        // MARK: - Helper Methods for XR

        func isUserPinching() -> Bool {
            xrInputState.leftHandPinching || xrInputState.rightHandPinching
        }

        func getPinchPosition() -> simd_float3? {
            if xrInputState.rightHandPinching {
                return xrInputState.rightHandPosition
            } else if xrInputState.leftHandPinching {
                return xrInputState.leftHandPosition
            }
            return nil
        }

        func getGazeTarget(maxDistance: Float = 10.0) -> simd_float3 {
            xrInputState.gazePosition + xrInputState.gazeDirection * maxDistance
        }
    #endif
}
