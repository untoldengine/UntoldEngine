//
//  ShadowEntityCacheTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

/// Covers RenderPasses' shadow entity candidate cache — specifically the
/// invalidation contract described in the shadow-cache-invalidation postmortem:
/// non-streaming entity loads must call RenderPasses.invalidateShadowEntityCache()
/// after ECS registration, or the entity silently never casts a shadow because the
/// cache was already rebuilt (shadowCacheDirty == false) before it existed.
@MainActor
final class ShadowEntityCacheTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        // Force a clean rebuild against the empty scene so no candidate state
        // leaks in from whatever the previous test class left in this singleton.
        RenderPasses.invalidateShadowEntityCache()
        _ = RenderPasses.shadowEntityCandidatesForTesting()
    }

    @discardableResult
    private func makeShadowCastingEntity(castsShadow: Bool = true, position: simd_float3 = .zero) -> EntityID {
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        scene.get(component: RenderComponent.self, for: entityId)?.castsShadow = castsShadow
        scene.get(component: WorldTransformComponent.self, for: entityId)?.space =
            matrix4x4Translation(position.x, position.y, position.z)
        return entityId
    }

    /// Reproduces the exact bug: a renderable entity created via a non-streaming
    /// load path is invisible to the shadow candidate cache until something calls
    /// invalidateShadowEntityCache() — creating the entity alone is not enough.
    func testShadowCacheRequiresInvalidationAfterNonStreamingEntityCreation() {
        let entityId = makeShadowCastingEntity()

        // No invalidation yet: the cache is still the clean-but-stale rebuild from
        // setUp, so the new entity must be absent. This is the bug reproduced.
        XCTAssertFalse(
            RenderPasses.shadowEntityCandidatesForTesting().contains(entityId),
            "A newly created shadow caster must not appear before the cache is invalidated"
        )

        RenderPasses.invalidateShadowEntityCache()

        XCTAssertTrue(
            RenderPasses.shadowEntityCandidatesForTesting().contains(entityId),
            "invalidateShadowEntityCache() must force a rebuild that picks up entities created since the last one"
        )
    }

    func testShadowEntityCandidatesExcludeNonShadowCastingEntity() {
        let entityId = makeShadowCastingEntity(castsShadow: false)
        RenderPasses.invalidateShadowEntityCache()

        XCTAssertFalse(RenderPasses.shadowEntityCandidatesForTesting().contains(entityId))
    }
}
