//
//  GaussianAsyncLoadTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

/// setEntityGaussianAsync(entityId:filename:withExtension:completion:) must behave like
/// setEntityMeshAsync -- callable directly with a completion closure, no Task/await needed at
/// the call site -- and must genuinely defer its work rather than running inline before
/// returning. This does NOT prove the parse/encode work happens off the main thread (that
/// guarantee comes from the internal Task.detached, and is validated by on-device Instruments
/// traces showing zero hangs, not by this test) -- a plain, non-detached Task{} would also pass
/// this assertion, since Task{} always defers its body regardless of actor inheritance. What
/// this catches is a regression back to a fully synchronous, no-Task-at-all implementation,
/// which is what the pre-#1249-fix `setEntityGaussianAsync` effectively was when awaited
/// directly from a MainActor context.
final class GaussianAsyncLoadTest: BaseRenderSetup {
    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        // The async load itself is the thing under test -- nothing to preload here.
    }

    func testSetEntityGaussianAsyncLoadsWithoutBlockingCallSite() {
        let entity = createEntity()

        let loaded = expectation(description: "Gaussian splat loaded asynchronously")
        var completionSuccess = false
        setEntityGaussianAsync(entityId: entity, filename: "test_gaussians", withExtension: "ply") { success in
            completionSuccess = success
            loaded.fulfill()
        }

        // setEntityGaussianAsync must return before the load finishes. This is the exact
        // behavior #1249's fix depends on: the old implementation awaited a plain synchronous
        // function with no thread-hop, so calling it from a MainActor context (like this test,
        // or GameScene.init()) ran the parse/encode work inline before yielding. If that
        // regresses, the component would already be attached by the time this assertion runs.
        XCTAssertNil(
            scene.get(component: GaussianComponent.self, for: entity),
            "setEntityGaussianAsync must not attach the component synchronously on the calling thread"
        )

        wait(for: [loaded], timeout: 15.0)

        XCTAssertTrue(completionSuccess, "The Gaussian splat should load successfully")
        let component = scene.get(component: GaussianComponent.self, for: entity)
        XCTAssertNotNil(component, "GaussianComponent should be attached once loading completes")
        XCTAssertGreaterThan(component?.splatCount ?? 0, 0)
    }
}
