//
//  RenderGraphResourcePlanTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class RenderGraphResourcePlanTest: XCTestCase {
    override func setUp() {
        super.setUp()
        RenderResourceRegistry.shared.removeAll()
    }

    override func tearDown() {
        RenderResourceRegistry.shared.removeAll()
        super.tearDown()
    }

    func testCompilationCapturesFirstAndLastResourceUse() throws {
        let resourceID = registerBuffer("test.plan.interval", lifetime: .transient)
        let compiled = try compileRenderGraph([
            "write": pass("write", uses: [.buffer(resourceID, access: .write)]),
            "middle": pass("middle", dependencies: ["write"]),
            "read": pass(
                "read",
                dependencies: ["middle"],
                uses: [.buffer(resourceID, access: .read)]
            ),
        ])

        let resource = try XCTUnwrap(
            compiled.resourcePlan.resource(kind: .buffer, id: resourceID.rawValue)
        )
        XCTAssertEqual(compiled.executionOrder, ["write", "middle", "read"])
        XCTAssertEqual(resource.firstUsePassIndex, 0)
        XCTAssertEqual(resource.lastUsePassIndex, 2)
        XCTAssertEqual(resource.passIDs, ["write", "read"])
        XCTAssertEqual(resource.lifetime, .transient)
    }

    func testCompatibleNonOverlappingTransientResourcesShareAliasSlot() throws {
        let firstID = registerBuffer("test.plan.alias.first", lifetime: .transient)
        let secondID = registerBuffer("test.plan.alias.second", lifetime: .transient)
        let compiled = try compileRenderGraph([
            "a-write": pass("a-write", uses: [.buffer(firstID, access: .write)]),
            "b-read": pass(
                "b-read",
                dependencies: ["a-write"],
                uses: [.buffer(firstID, access: .read)]
            ),
            "c-write": pass(
                "c-write",
                dependencies: ["b-read"],
                uses: [.buffer(secondID, access: .write)]
            ),
            "d-read": pass(
                "d-read",
                dependencies: ["c-write"],
                uses: [.buffer(secondID, access: .read)]
            ),
        ])

        let first = try XCTUnwrap(
            compiled.resourcePlan.resource(kind: .buffer, id: firstID.rawValue)
        )
        let second = try XCTUnwrap(
            compiled.resourcePlan.resource(kind: .buffer, id: secondID.rawValue)
        )
        XCTAssertEqual(first.aliasSlotID, second.aliasSlotID)
        XCTAssertEqual(compiled.resourcePlan.transientAliasSlots.count, 1)
        XCTAssertEqual(
            compiled.resourcePlan.transientAliasSlots[0].resourceIDs,
            [firstID.rawValue, secondID.rawValue]
        )
    }

    func testOverlappingTransientResourcesUseDifferentAliasSlots() throws {
        let firstID = registerBuffer("test.plan.overlap.first", lifetime: .transient)
        let secondID = registerBuffer("test.plan.overlap.second", lifetime: .transient)
        let compiled = try compileRenderGraph([
            "a-first": pass("a-first", uses: [.buffer(firstID, access: .write)]),
            "b-second": pass(
                "b-second",
                dependencies: ["a-first"],
                uses: [.buffer(secondID, access: .write)]
            ),
            "c-read": pass(
                "c-read",
                dependencies: ["b-second"],
                uses: [
                    .buffer(firstID, access: .read),
                    .buffer(secondID, access: .read),
                ]
            ),
        ])

        let first = compiled.resourcePlan.resource(kind: .buffer, id: firstID.rawValue)
        let second = compiled.resourcePlan.resource(kind: .buffer, id: secondID.rawValue)
        XCTAssertNotEqual(first?.aliasSlotID, second?.aliasSlotID)
        XCTAssertEqual(compiled.resourcePlan.transientAliasSlots.count, 2)
    }

    func testPersistentResourcesAreExcludedFromAliasSlots() throws {
        let resourceID = registerBuffer("test.plan.persistent", lifetime: .persistent)
        let compiled = try compileRenderGraph([
            "write": pass("write", uses: [.buffer(resourceID, access: .write)]),
        ])

        let resource = try XCTUnwrap(
            compiled.resourcePlan.resource(kind: .buffer, id: resourceID.rawValue)
        )
        XCTAssertEqual(resource.lifetime, .persistent)
        XCTAssertNil(resource.aliasSlotID)
        XCTAssertTrue(compiled.resourcePlan.transientAliasSlots.isEmpty)
    }

    func testIncompatibleTransientResourcesUseDifferentAliasSlots() throws {
        let firstID = registerBuffer(
            "test.plan.incompatible.first",
            length: 64,
            lifetime: .transient
        )
        let secondID = registerBuffer(
            "test.plan.incompatible.second",
            length: 128,
            lifetime: .transient
        )
        let compiled = try compileRenderGraph([
            "first": pass("first", uses: [.buffer(firstID, access: .write)]),
            "second": pass(
                "second",
                dependencies: ["first"],
                uses: [.buffer(secondID, access: .write)]
            ),
        ])

        XCTAssertEqual(compiled.resourcePlan.transientAliasSlots.count, 2)
    }

    func testTransientTexturesRequireExactDescriptorCompatibility() throws {
        let firstID = registerTexture(
            "test.plan.texture.first",
            pixelFormat: .rgba8Unorm
        )
        let secondID = registerTexture(
            "test.plan.texture.second",
            pixelFormat: .rgba16Float
        )
        let compiled = try compileRenderGraph([
            "first": pass("first", uses: [.texture(firstID, access: .renderTarget)]),
            "second": pass(
                "second",
                dependencies: ["first"],
                uses: [.texture(secondID, access: .renderTarget)]
            ),
        ])

        XCTAssertEqual(compiled.resourcePlan.transientAliasSlots.count, 2)
        XCTAssertEqual(
            compiled.resourcePlan.transientAliasSlots.map(\.kind),
            [.texture, .texture]
        )
    }

    func testResourcePlanIsDeterministicAndImmutable() throws {
        let firstID = registerBuffer("test.plan.snapshot.first", lifetime: .transient)
        let secondID = registerBuffer("test.plan.snapshot.second", lifetime: .transient)
        let firstPass = pass("first", uses: [.buffer(firstID, access: .write)])
        let secondPass = pass(
            "second",
            dependencies: ["first"],
            uses: [.buffer(secondID, access: .write)]
        )
        var forward: [String: RenderPass] = [:]
        var reverse: [String: RenderPass] = [:]
        forward[firstPass.id] = firstPass
        forward[secondPass.id] = secondPass
        reverse[secondPass.id] = secondPass
        reverse[firstPass.id] = firstPass

        let firstCompilation = try compileRenderGraph(forward)
        let secondCompilation = try compileRenderGraph(reverse)
        let capturedPlan = firstCompilation.resourcePlan
        RenderResourceRegistry.shared.registerBuffer(
            RenderExtensionBufferDescriptor(id: firstID, length: 256)
        )

        XCTAssertEqual(firstCompilation.resourcePlan, secondCompilation.resourcePlan)
        XCTAssertEqual(firstCompilation.resourcePlan, capturedPlan)
    }

    private func registerBuffer(
        _ id: String,
        length: Int = 64,
        lifetime: RenderExtensionResourceLifetime
    ) -> RenderBufferResourceID {
        let resourceID = RenderBufferResourceID(id)
        RenderResourceRegistry.shared.registerBuffer(
            RenderExtensionBufferDescriptor(
                id: resourceID,
                length: length,
                lifetime: lifetime
            )
        )
        return resourceID
    }

    private func registerTexture(
        _ id: String,
        pixelFormat: MTLPixelFormat
    ) -> RenderTextureResourceID {
        let resourceID = RenderTextureResourceID(id)
        RenderResourceRegistry.shared.registerTexture(
            RenderExtensionTextureDescriptor(
                id: resourceID,
                size: .fixed(width: 8, height: 8),
                pixelFormat: pixelFormat,
                usage: .renderTarget,
                lifetime: .transient
            )
        )
        return resourceID
    }

    private func pass(
        _ id: String,
        dependencies: [String] = [],
        uses resources: [RenderGraphResourceUsage] = []
    ) -> RenderPass {
        RenderPass(
            id: id,
            dependencies: dependencies,
            execute: nil,
            resourceUsages: resources
        )
    }
}
