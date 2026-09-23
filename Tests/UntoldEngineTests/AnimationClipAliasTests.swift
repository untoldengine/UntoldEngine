//
//  AnimationClipAliasTests.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

/// Coverage for the preferred-name/embedded-name aliasing that
/// `registerRuntimeAnimationClips` performs when an asset's single embedded
/// clip name (e.g. a default Blender action name like "Anim") differs from
/// the caller-supplied preferred name (e.g. a filename-derived name like
/// "hol_idle_anim"). Both names must keep working as lookup keys, but
/// `getAllAnimationClips` must report one display name per logical
/// animation, and `removeAnimationClip` must remove every alias together.
@MainActor
final class AnimationClipAliasTests: XCTestCase {
    // MARK: - Fixtures

    private func makeRuntimeClip(name: String, rootTranslationY: Float = 0) -> RuntimeAnimationClip {
        let channel = RuntimeAnimationChannel(
            jointPath: "root",
            translations: [.init(time: 0.0, value: simd_float3(0, rootTranslationY, 0))]
        )
        return RuntimeAnimationClip(name: name, duration: 1.0, channels: [channel])
    }

    // MARK: - registerRuntimeAnimationClips aliasing

    func testAliasIsCreatedWhenPreferredNameDiffersFromEmbeddedName() {
        let component = AnimationComponent()
        let runtimeClip = makeRuntimeClip(name: "Anim")

        let registeredNames = registerRuntimeAnimationClips([runtimeClip], preferredName: "hol_idle_anim", to: component)

        XCTAssertEqual(Set(registeredNames), ["Anim", "hol_idle_anim"])
        XCTAssertTrue(component.animationClips["Anim"] === component.animationClips["hol_idle_anim"],
                      "Both keys should reference the same AnimationClip instance")
        XCTAssertEqual(component.getAllAnimationClips(), ["hol_idle_anim"],
                       "Only the preferred name should be a display name")
    }

    func testNoAliasWhenPreferredNameMatchesEmbeddedName() {
        let component = AnimationComponent()
        let runtimeClip = makeRuntimeClip(name: "walk")

        let registeredNames = registerRuntimeAnimationClips([runtimeClip], preferredName: "walk", to: component)

        XCTAssertEqual(registeredNames, ["walk"])
        XCTAssertEqual(component.animationClips.count, 1)
        XCTAssertEqual(component.getAllAnimationClips(), ["walk"])
    }

    func testMultiClipAssetListsEveryClipWithoutAliasing() {
        let component = AnimationComponent()
        let clips = [makeRuntimeClip(name: "Anim"), makeRuntimeClip(name: "Anim2")]

        let registeredNames = registerRuntimeAnimationClips(clips, preferredName: "ignoredForMultiClip", to: component)

        XCTAssertEqual(Set(registeredNames), ["Anim", "Anim2"])
        XCTAssertEqual(component.getAllAnimationClips().sorted(), ["Anim", "Anim2"])
    }

    func testIndependentlyExportedClipsSharingEmbeddedNameStayDistinctByPreferredName() {
        let component = AnimationComponent()
        let clipA = makeRuntimeClip(name: "Anim", rootTranslationY: 1)
        let clipB = makeRuntimeClip(name: "Anim", rootTranslationY: 9)

        _ = registerRuntimeAnimationClips([clipA], preferredName: "walk_anim", to: component)
        _ = registerRuntimeAnimationClips([clipB], preferredName: "run_anim", to: component)

        XCTAssertEqual(component.getAllAnimationClips().sorted(), ["run_anim", "walk_anim"],
                       "Each independently exported clip must be listed once under its own preferred name")
        XCTAssertFalse(component.animationClips["walk_anim"] === component.animationClips["run_anim"],
                        "Distinct clips must not collapse into the same instance")
        XCTAssertEqual(component.animationClips["walk_anim"]?.getPose(at: 0, jointPath: "root")?.columns.3.y, 1)
        XCTAssertEqual(component.animationClips["run_anim"]?.getPose(at: 0, jointPath: "root")?.columns.3.y, 9)
    }

    func testReregisteringUnderSamePreferredNameWithChangedEmbeddedNamePrunesStaleAlias() {
        let component = AnimationComponent()
        let original = makeRuntimeClip(name: "Anim", rootTranslationY: 1)
        _ = registerRuntimeAnimationClips([original], preferredName: "hol_idle_anim", to: component)
        XCTAssertNotNil(component.animationClips["Anim"])

        // Re-export changed the embedded clip name but the caller still asks
        // for the same preferred/display name.
        let replacement = makeRuntimeClip(name: "Idle", rootTranslationY: 9)
        _ = registerRuntimeAnimationClips([replacement], preferredName: "hol_idle_anim", to: component)

        XCTAssertNil(component.animationClips["Anim"], "Stale alias from the replaced clip must not linger")
        XCTAssertTrue(component.animationClips["Idle"] === component.animationClips["hol_idle_anim"])
        XCTAssertEqual(component.getAllAnimationClips(), ["hol_idle_anim"])
        XCTAssertEqual(component.animationClips["hol_idle_anim"]?.getPose(at: 0, jointPath: "root")?.columns.3.y, 9)
    }

    // MARK: - removeAnimationClip cascades across aliases

    func testRemoveAnimationClipByPreferredNameRemovesEmbeddedAliasToo() {
        let component = AnimationComponent()
        let runtimeClip = makeRuntimeClip(name: "Anim")
        _ = registerRuntimeAnimationClips([runtimeClip], preferredName: "hol_idle_anim", to: component)

        component.removeAnimationClip(animationClip: "hol_idle_anim")

        XCTAssertNil(component.animationClips["hol_idle_anim"])
        XCTAssertNil(component.animationClips["Anim"])
        XCTAssertTrue(component.getAllAnimationClips().isEmpty)
    }

    func testRemoveAnimationClipByEmbeddedAliasRemovesPreferredNameToo() {
        let component = AnimationComponent()
        let runtimeClip = makeRuntimeClip(name: "Anim")
        _ = registerRuntimeAnimationClips([runtimeClip], preferredName: "hol_idle_anim", to: component)

        component.removeAnimationClip(animationClip: "Anim")

        XCTAssertNil(component.animationClips["Anim"])
        XCTAssertNil(component.animationClips["hol_idle_anim"])
        XCTAssertTrue(component.getAllAnimationClips().isEmpty)
    }

    func testRemoveAnimationClipDoesNotAffectUnrelatedClips() {
        let component = AnimationComponent()
        _ = registerRuntimeAnimationClips([makeRuntimeClip(name: "Anim")], preferredName: "hol_idle_anim", to: component)
        _ = registerRuntimeAnimationClips([makeRuntimeClip(name: "walk")], preferredName: "walk", to: component)

        component.removeAnimationClip(animationClip: "hol_idle_anim")

        XCTAssertEqual(component.getAllAnimationClips(), ["walk"])
    }

    // MARK: - Engine-level lookup/playback through aliases (changeAnimation, entity-level API)

    private func makeAliasedEntity() -> EntityID {
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)

        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: ["root"],
            parentIndices: [nil],
            bindTransforms: [.identity],
            restTransforms: [.identity]
        )
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton =
            Skeleton(runtimeSkeleton: runtimeSkeleton)

        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)!
        _ = registerRuntimeAnimationClips([makeRuntimeClip(name: "Anim")], preferredName: "hol_idle_anim", to: animationComponent)
        return entityId
    }

    func testChangeAnimationPlaysClipThroughEitherAliasName() throws {
        resetEngineTestState()
        let entityId = makeAliasedEntity()
        defer { destroyEntity(entityId: entityId) }

        changeAnimation(entityId: entityId, name: "Anim", transitionHalflife: 0)
        let animationComponent = try XCTUnwrap(scene.get(component: AnimationComponent.self, for: entityId))
        XCTAssertTrue(animationComponent.currentAnimation === animationComponent.animationClips["hol_idle_anim"],
                      "Looking up by the embedded alias should resolve the same logical clip")

        changeAnimation(entityId: entityId, name: "hol_idle_anim", transitionHalflife: 0)
        XCTAssertTrue(animationComponent.currentAnimation === animationComponent.animationClips["Anim"],
                      "Looking up by the preferred name should resolve the same logical clip")
    }

    func testEntityLevelGetAllAnimationClipsReturnsOneDisplayName() {
        resetEngineTestState()
        let entityId = makeAliasedEntity()
        defer { destroyEntity(entityId: entityId) }

        XCTAssertEqual(getAllAnimationClips(entityId: entityId), ["hol_idle_anim"])
    }

    func testEntityLevelRemoveAnimationClipClearsBothAliases() {
        resetEngineTestState()
        let entityId = makeAliasedEntity()
        defer { destroyEntity(entityId: entityId) }

        removeAnimationClip(entityId: entityId, animationClip: "hol_idle_anim")

        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)
        XCTAssertTrue(getAllAnimationClips(entityId: entityId).isEmpty)
        XCTAssertNil(animationComponent?.animationClips["Anim"])
        XCTAssertNil(animationComponent?.animationClips["hol_idle_anim"])
    }
}
