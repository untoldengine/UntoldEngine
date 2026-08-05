//
//  UntoldViewOptionsTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import MetalKit
import simd
@testable import UntoldEngine
import XCTest

/// Covers the runtime view options: struct semantics, the UntoldView
/// modifiers, and the coordinator-side diffing that applies changes to a
/// live MTKView. None of this needs a Metal device.
@MainActor
final class UntoldViewOptionsTests: XCTestCase {
    // MARK: - Struct semantics

    func testDefaults() {
        let options = UntoldViewOptions.default

        XCTAssertEqual(options.preferredFramesPerSecond, 60)
        XCTAssertFalse(options.isPaused)
        XCTAssertEqual(options.clearColor, simd_float4(0, 0, 0, 1))
    }

    func testEquality() {
        XCTAssertEqual(UntoldViewOptions(), UntoldViewOptions.default)
        XCTAssertNotEqual(UntoldViewOptions(preferredFramesPerSecond: 30), UntoldViewOptions.default)
        XCTAssertNotEqual(UntoldViewOptions(isPaused: true), UntoldViewOptions.default)
        XCTAssertNotEqual(UntoldViewOptions(clearColor: simd_float4(1, 0, 0, 1)), UntoldViewOptions.default)
    }

    // MARK: - UntoldView modifiers

    func testUntoldViewModifiersUpdateOptions() {
        let view = UntoldView(renderer: nil) {}

        XCTAssertEqual(view.options, .default)
        XCTAssertEqual(view.preferredFramesPerSecond(30).options.preferredFramesPerSecond, 30)
        XCTAssertTrue(view.paused(true).options.isPaused)

        let replaced = view.options(UntoldViewOptions(preferredFramesPerSecond: 120, isPaused: true))
        XCTAssertEqual(replaced.options.preferredFramesPerSecond, 120)
        XCTAssertTrue(replaced.options.isPaused)
    }

    func testUntoldViewModifiersDoNotMutateOriginal() {
        let view = UntoldView(renderer: nil) {}
        _ = view.preferredFramesPerSecond(30)

        XCTAssertEqual(view.options.preferredFramesPerSecond, 60)
    }

    // MARK: - Coordinator apply diffing

    func testFirstApplySetsEveryProperty() {
        let coordinator = SceneView.Coordinator()
        let view = MTKView()
        let options = UntoldViewOptions(
            preferredFramesPerSecond: 30,
            isPaused: true,
            clearColor: simd_float4(0.5, 0.25, 0, 1)
        )

        coordinator.apply(options, to: view)

        XCTAssertEqual(view.preferredFramesPerSecond, 30)
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(view.clearColor.red, 0.5, accuracy: 1e-6)
        XCTAssertEqual(view.clearColor.green, 0.25, accuracy: 1e-6)
        XCTAssertEqual(coordinator.appliedOptions, options)
    }

    func testApplyOnlyTouchesChangedProperties() {
        let coordinator = SceneView.Coordinator()
        let view = MTKView()
        coordinator.apply(.default, to: view)

        // Perturb the view behind the coordinator's back: if apply diffs
        // correctly, an FPS-only change must leave these values alone.
        view.isPaused = true
        view.clearColor = MTLClearColor(red: 0.9, green: 0, blue: 0, alpha: 1)

        var options = UntoldViewOptions.default
        options.preferredFramesPerSecond = 120
        coordinator.apply(options, to: view)

        XCTAssertEqual(view.preferredFramesPerSecond, 120)
        XCTAssertTrue(view.isPaused, "Unchanged isPaused option must not be re-applied")
        XCTAssertEqual(view.clearColor.red, 0.9, accuracy: 1e-6, "Unchanged clearColor option must not be re-applied")
    }

    func testApplyWithEqualOptionsIsANoOp() {
        let coordinator = SceneView.Coordinator()
        let view = MTKView()
        coordinator.apply(.default, to: view)

        view.preferredFramesPerSecond = 15
        coordinator.apply(.default, to: view)

        XCTAssertEqual(view.preferredFramesPerSecond, 15, "Equal options must not touch the view at all")
    }
}
