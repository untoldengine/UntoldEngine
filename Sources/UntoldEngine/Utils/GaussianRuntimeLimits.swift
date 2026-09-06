//
//  GaussianRuntimeLimits.swift
//  UntoldEngine
//
//  Per-entity size limits of the Gaussian splat runtime. Every loaded splat keeps about
//  270 bytes resident on the GPU (encoded record, per-frame precomputed data, sort keys and
//  visible indices for every frame in flight, spherical harmonics), so the cap is a memory
//  guard per platform, not a format limit. Cooks that must load everywhere use the mobile
//  figure as their splat budget (`UntoldGSCookOptions.maxSplatCount`).
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum GaussianRuntimeLimits {
    /// Apple Vision Pro, iPhone, iPad and Apple TV: 5,242,880 splats per entity (about 1.4 GB).
    public static let maxSplatsPerEntityMobile = 1024 * 1024 * 5
    /// Mac: 16,777,216 splats per entity (about 4.5 GB of unified memory).
    public static let maxSplatsPerEntityMac = 1024 * 1024 * 16

    /// The cap the running binary enforces when a splat asset loads.
    public static var maxSplatsPerEntity: Int {
        #if os(macOS)
            maxSplatsPerEntityMac
        #else
            maxSplatsPerEntityMobile
        #endif
    }
}
