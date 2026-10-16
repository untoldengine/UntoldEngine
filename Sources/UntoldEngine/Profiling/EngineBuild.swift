//
//  EngineBuild.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/// How the engine module itself was compiled, for a measurement to say so: an app's Debug
/// configuration builds the package at `-Onone`, and a frame that fits comfortably when the
/// engine is optimized is then bound by the CPU encoding it (measured on a headset: the
/// opaque draws took five times longer to encode, and the GPU downclocked while it waited).
public enum EngineBuild {
    /// Whether the engine module was compiled with the optimizer on. Read here, inside the
    /// module and never inlined, so it reports the engine's own build and not the caller's.
    @inline(never)
    public static var isOptimized: Bool {
        !_isDebugAssertConfiguration()
    }
}
