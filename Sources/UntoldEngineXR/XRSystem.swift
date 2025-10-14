//
//  XRSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#if os(visionOS)
    import Metal

    @MainActor
    public protocol XRSystem: AnyObject {
        /// Start the visionOS-driven render loop.
        func start()
        /// Stop the loop (optional, but handy during teardown).
        func stop()
    }

#endif
