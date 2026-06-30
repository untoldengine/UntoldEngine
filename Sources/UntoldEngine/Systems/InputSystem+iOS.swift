//
//  InputSystem+iOS.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if os(iOS)
    import UIKit
#endif

// MARK: - iOS Touch State

/// Dedicated state for iOS touch gestures. Populated only when running on iOS;
/// all fields stay at their default values on other platforms.
public struct IOSTouchState {
    // Single-finger drag
    public var isDragging = false
    public var dragX: Float = 0
    public var dragY: Float = 0
    public var dragDeltaX: Float = 0
    public var dragDeltaY: Float = 0
    public var dragGestureState: PanGestureState?

    // Tap — brief pulse; auto-clears after ~0.1 s
    public var tapped = false
    public var tapX: Float = 0
    public var tapY: Float = 0

    // Double tap — brief pulse; auto-clears after ~0.1 s
    public var doubleTapped = false
    public var doubleTapX: Float = 0
    public var doubleTapY: Float = 0

    // Two-finger pan
    public var twoFingerPanning = false
    public var twoFingerDeltaX: Float = 0
    public var twoFingerDeltaY: Float = 0

    // Pinch — pinchScaleDelta is the change in scale per frame (positive = spreading)
    public var isPinching = false
    public var pinchScaleDelta: Float = 0

    public init() {}
}

// MARK: - InputSystem iOS Extension

public extension InputSystem {
    #if !os(iOS)
        func registerTouchEvents(view _: Any) {}
        func unregisterTouchEvents() {}
    #else
        func registerTouchEvents(view: UIView) {
            iosTouchView = view

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            pan.minimumNumberOfTouches = 1
            pan.maximumNumberOfTouches = 1
            view.addGestureRecognizer(pan)
            iosTouchGestureRecognizers.append(pan)

            let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
            twoFingerPan.minimumNumberOfTouches = 2
            twoFingerPan.maximumNumberOfTouches = 2
            view.addGestureRecognizer(twoFingerPan)
            iosTouchGestureRecognizers.append(twoFingerPan)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
            view.addGestureRecognizer(pinch)
            iosTouchGestureRecognizers.append(pinch)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
            view.addGestureRecognizer(tap)
            iosTouchGestureRecognizers.append(tap)

            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture(_:)))
            doubleTap.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleTap)
            iosTouchGestureRecognizers.append(doubleTap)

            // Single tap must wait for the double-tap recognizer to fail first
            tap.require(toFail: doubleTap)
        }

        func unregisterTouchEvents() {
            for recognizer in iosTouchGestureRecognizers {
                iosTouchView?.removeGestureRecognizer(recognizer)
            }
            iosTouchGestureRecognizers.removeAll()
            iosTouchView = nil
            iosTouchState = IOSTouchState()
        }

        // MARK: - Single-finger drag

        @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)

            switch gesture.state {
            case .began:
                iosTouchState.isDragging = true
                iosTouchState.dragGestureState = .began
                iosTouchState.dragX = Float(location.x)
                iosTouchState.dragY = Float(location.y)
                iosTouchState.dragDeltaX = 0
                iosTouchState.dragDeltaY = 0

            case .changed:
                let translation = gesture.translation(in: view)
                iosTouchState.dragGestureState = .changed
                iosTouchState.dragX = Float(location.x)
                iosTouchState.dragY = Float(location.y)
                iosTouchState.dragDeltaX = Float(translation.x)
                iosTouchState.dragDeltaY = Float(translation.y)
                gesture.setTranslation(.zero, in: view)

            case .ended, .cancelled:
                iosTouchState.isDragging = false
                iosTouchState.dragGestureState = .ended
                iosTouchState.dragDeltaX = 0
                iosTouchState.dragDeltaY = 0

            default:
                break
            }
        }

        // MARK: - Two-finger pan

        @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }

            switch gesture.state {
            case .began:
                iosTouchState.twoFingerPanning = true
                iosTouchState.twoFingerDeltaX = 0
                iosTouchState.twoFingerDeltaY = 0

            case .changed:
                let translation = gesture.translation(in: view)
                iosTouchState.twoFingerDeltaX = Float(translation.x)
                iosTouchState.twoFingerDeltaY = Float(translation.y)
                gesture.setTranslation(.zero, in: view)

            case .ended, .cancelled:
                iosTouchState.twoFingerPanning = false
                iosTouchState.twoFingerDeltaX = 0
                iosTouchState.twoFingerDeltaY = 0

            default:
                break
            }
        }

        // MARK: - Pinch

        @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                iosTouchState.isPinching = true
                iosTouchState.pinchScaleDelta = 0
                previousScale = gesture.scale

            case .changed:
                let current = gesture.scale
                iosTouchState.pinchScaleDelta = Float(current - previousScale)
                previousScale = current

            case .ended, .cancelled:
                iosTouchState.isPinching = false
                iosTouchState.pinchScaleDelta = 0
                previousScale = 1.0

            default:
                break
            }
        }

        // MARK: - Tap

        @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            iosTouchState.tapX = Float(location.x)
            iosTouchState.tapY = Float(location.y)
            iosTouchState.tapped = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.iosTouchState.tapped = false
            }
        }

        // MARK: - Double tap

        @objc private func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            iosTouchState.doubleTapX = Float(location.x)
            iosTouchState.doubleTapY = Float(location.y)
            iosTouchState.doubleTapped = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.iosTouchState.doubleTapped = false
            }
        }
    #endif
}
