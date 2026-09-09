//
//  GaussianRuntimeLimits.swift
//  UntoldEngine
//
//  Size limits of the Gaussian splat runtime. A `.untoldgs` splat keeps its 16-byte core record
//  and its spherical harmonics resident on the GPU and nothing else per splat — the frame's
//  working set (records, keys) is shared by every entity and sized to a budget, not to the
//  resident total — so the per-entity cap is a memory guard per platform, not a format limit.
//  A `.ply` (or a `.untoldgs` decoded on the CPU) keeps the 48-byte encoded record and a
//  visible index per frame in flight instead, about 60 bytes per splat plus harmonics. Cooks
//  that must load everywhere use the mobile figure as their splat budget
//  (`UntoldGSCookOptions.maxSplatCount`).
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum GaussianRuntimeLimits {
    /// Apple Vision Pro, iPhone, iPad and Apple TV: 20,000,000 splats per entity (about 320 MB
    /// of packed records, 1.2 GB with degree-3 harmonics).
    public static let maxSplatsPerEntityMobile = 20_000_000
    /// Mac: 40,000,000 splats per entity (about 640 MB of packed records, 2.4 GB with
    /// degree-3 harmonics).
    public static let maxSplatsPerEntityMac = 40_000_000

    /// The cap the running binary enforces when a splat asset loads.
    public static var maxSplatsPerEntity: Int {
        #if os(macOS)
            maxSplatsPerEntityMac
        #else
            maxSplatsPerEntityMobile
        #endif
    }

    /// Default size of the frame's shared working set, in splats: the most the frame compacts,
    /// sorts and draws across every splat entity. Each record costs 72 bytes per frame in flight
    /// (`GaussianSharedWorkingSet.bytesPerSplatPerSlot`), so a million splats hold 216 MB.
    public static let workingSetSplatsMobile = 1_000_000
    public static let workingSetSplatsMac = 6_000_000

    public static var workingSetSplats: Int {
        #if os(macOS)
            workingSetSplatsMac
        #else
            workingSetSplatsMobile
        #endif
    }

    /// Replaces the default working-set size (and the memory-budget clamp on it) with an exact
    /// figure; nil restores the default. For tests and applications that know their scene.
    public static var workingSetSplatsOverride: Int? {
        get { storage.override }
        set { storage.override = newValue }
    }

    private final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var _override: Int?
        var override: Int? {
            get { lock.lock(); defer { lock.unlock() }; return _override }
            set { lock.lock(); _override = newValue.map { max(1, $0) }; lock.unlock() }
        }
    }

    private static let storage = Storage()
}
