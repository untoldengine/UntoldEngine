//
//  PulseClock.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// A clock shared by everything that pulses, so it all moves in step. It stands in for a
/// package's runtime: state that both game code and the package's editor side reach.
public final class PulseClock {
    public static let shared = PulseClock()

    public static let defaultFrequency: Float = 0.5

    /// Pulses per second.
    public var frequency: Float = PulseClock.defaultFrequency

    private init() {}

    /// A value between -1 and 1 for a moment in seconds.
    public func wave(at time: Float) -> Float {
        sin(time * frequency * 2 * .pi)
    }

    public func reset() {
        frequency = PulseClock.defaultFrequency
    }
}
