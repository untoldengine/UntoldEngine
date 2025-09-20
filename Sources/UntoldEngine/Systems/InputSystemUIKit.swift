//
//  InputSystemUIKit.swift
//  Untold Engine
//  Created by Harold Serrano on 10/19/25.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

#if os(iOS)
import UIKit

extension InputSystem {
    public func setupGestureRecognizers(view: UIView) {
        let pan   = UIPanGestureRecognizer(target: self, action: #selector(handlePanUIKit(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchUIKit(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
    }
    
    public func setupEventMonitors() {}

    @objc private func handlePanUIKit(_ gr: UIPanGestureRecognizer) {
        guard let view = gr.view else { return }
        let t = gr.translation(in: view)
        switch gr.state {
        case .began:  initialPanLocation = t ; currentPanGestureState = .began
        case .changed:
            var dx = t.x - (initialPanLocation?.x ?? t.x)
            var dy = t.y - (initialPanLocation?.y ?? t.y)
            if abs(dx) < abs(dy) { dx = 0 } else { dy = 0; dx = -dx }
            if abs(dx) <= 1 { dx = 0 } ; if abs(dy) <= 1 { dy = 0 }
            panDelta = .init(Float(dx), Float(dy))
            currentPanGestureState = .changed
            initialPanLocation = t
            // TODO: call your camera orbit: orbitAround(entityId:..., uPosition: panDelta * 0.005)
        case .ended, .cancelled, .failed:
            panDelta = .zero ; initialPanLocation = nil ; currentPanGestureState = .ended
        default: break
        }
    }

    @objc private func handlePinchUIKit(_ gr: UIPinchGestureRecognizer) {
        switch gr.state {
        case .began: previousScale = gr.scale ; currentPinchGestureState = .began
        case .changed:
            let delta = gr.scale - previousScale
            pinchDelta = 3.0 * .init(0, 0, Float(delta))
            previousScale = gr.scale
            currentPinchGestureState = .changed
        case .ended, .cancelled, .failed:
            previousScale = 1 ; currentPinchGestureState = .ended
        default: break
        }
    }
}
#endif

