//
//  InputSystem+iOS.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#if os(iOS)
    import UIKit
#endif

public extension InputSystem {
    #if !os(iOS)
        func registerTouchEvents(view _: Any) {}
        func unregisterTouchEvents() {}
    #else
        func registerTouchEvents(view: UIView) {
            // Pan gesture (single finger drag - equivalent to mouse drag)
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            panGesture.minimumNumberOfTouches = 1
            panGesture.maximumNumberOfTouches = 1
            view.addGestureRecognizer(panGesture)

            // Two-finger pan (for camera movement/orbiting)
            let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
            twoFingerPan.minimumNumberOfTouches = 2
            twoFingerPan.maximumNumberOfTouches = 2
            view.addGestureRecognizer(twoFingerPan)

            // Pinch gesture (for zooming)
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
            view.addGestureRecognizer(pinchGesture)

            // Tap gesture (for selection/interaction)
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
            view.addGestureRecognizer(tapGesture)

            // Double tap gesture
            let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture(_:)))
            doubleTapGesture.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleTapGesture)

            // Make sure single tap doesn't conflict with double tap
            tapGesture.require(toFail: doubleTapGesture)
        }

        // MARK: - Pan Gesture (Single Finger)

        @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }

            let location = gesture.location(in: view)
            let translation = gesture.translation(in: view)

            switch gesture.state {
            case .began:
                currentPanGestureState = .began
                initialPanLocation = location
                lastMouseX = Float(location.x)
                lastMouseY = Float(location.y)
                mouseX = lastMouseX
                mouseY = lastMouseY
                mouseActive = true

            case .changed:
                currentPanGestureState = .changed
                lastMouseX = mouseX
                lastMouseY = mouseY
                mouseX = Float(location.x)
                mouseY = Float(location.y)

                mouseDeltaX = Float(translation.x)
                mouseDeltaY = Float(translation.y)

                panDelta.x = Float(translation.x)
                panDelta.y = Float(translation.y)

                // Reset translation to get delta for next frame
                gesture.setTranslation(.zero, in: view)

            case .ended, .cancelled:
                currentPanGestureState = .ended
                mouseActive = false
                mouseDeltaX = 0
                mouseDeltaY = 0
                panDelta = .init(0, 0)

            default:
                break
            }
        }

        // MARK: - Two-Finger Pan (Camera Orbit)

        @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }

            let translation = gesture.translation(in: view)

            switch gesture.state {
            case .began:
                cameraControlMode = .orbiting
                currentPanGestureState = .began

            case .changed:
                currentPanGestureState = .changed
                panDelta.x = Float(translation.x)
                panDelta.y = Float(translation.y)

                // Reset translation for next frame
                gesture.setTranslation(.zero, in: view)

            case .ended, .cancelled:
                currentPanGestureState = .ended
                cameraControlMode = .idle
                panDelta = .init(0, 0)

            default:
                break
            }
        }

        // MARK: - Pinch Gesture (Zoom)

        @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                currentPinchGestureState = .began
                previousScale = gesture.scale

            case .changed:
                currentPinchGestureState = .changed
                let currentScale = gesture.scale
                let scaleDelta = currentScale - previousScale

                // Update pinch delta for zoom
                pinchDelta.z = Float(scaleDelta)

                previousScale = currentScale

            case .ended, .cancelled:
                currentPinchGestureState = .ended
                pinchDelta = .init(0, 0, 0)
                previousScale = 1.0

            default:
                break
            }
        }

        // MARK: - Tap Gestures

        @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)

            mouseX = Float(location.x)
            mouseY = Float(location.y)

            // Simulate a quick mouse press/release
            keyState.leftMousePressed = true
            // You might want to add a delegate method here to notify about tap
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.keyState.leftMousePressed = false
            }
        }

        @objc private func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)

            mouseX = Float(location.x)
            mouseY = Float(location.y)

            // You can add custom double-tap handling here
            // For example, reset camera or select entity
        }
    #endif
}
