//
//  RenderGraphOptimizationReportTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class RenderGraphOptimizationReportTest: XCTestCase {
    override func setUp() {
        super.setUp()
        RenderResourceRegistry.shared.removeAll()
    }

    override func tearDown() {
        RenderResourceRegistry.shared.removeAll()
        super.tearDown()
    }

    func testReportCapturesGraphAndResourceStatistics() throws {
        let first = registerBuffer("test.audit.first", lifetime: .transient)
        let persistent = registerBuffer("test.audit.persistent", lifetime: .persistent)
        let second = registerBuffer("test.audit.second", lifetime: .transient)
        let compiled = try compileRenderGraph([
            "first": pass("first", uses: [.buffer(first, access: .write)]),
            "persistent": pass(
                "persistent",
                dependencies: ["first"],
                uses: [.buffer(persistent, access: .write)]
            ),
            "second": pass(
                "second",
                dependencies: ["persistent"],
                uses: [.buffer(second, access: .write)]
            ),
        ])

        XCTAssertEqual(
            compiled.optimizationReport.statistics,
            CompiledRenderGraphStatistics(
                passCount: 3,
                dependencyCount: 2,
                explicitDependencyCount: 2,
                inferredDependencyCount: 0,
                usedResourceCount: 3,
                persistentResourceCount: 1,
                transientResourceCount: 2,
                transientAliasSlotCount: 1,
                aliasedResourceCount: 2,
                backingStoreReductionOpportunityCount: 1,
                unusedDeclaredResourceCount: 0,
                redundantDependencyCount: 0
            )
        )
        XCTAssertTrue(compiled.optimizationReport.isResourcePlanValid)
    }

    func testReportFindsRedundantExplicitDependency() throws {
        let compiled = try compileRenderGraph([
            "a": pass("a"),
            "b": pass("b", dependencies: ["a"]),
            "c": pass("c", dependencies: ["a", "b"]),
        ])

        XCTAssertEqual(
            compiled.optimizationReport.redundantDependencies,
            [
                CompiledRenderGraphRedundantDependency(
                    passID: "c",
                    dependencyID: "a",
                    inferred: false
                ),
            ]
        )
    }

    func testReportFindsRedundantInferredHazardDependency() throws {
        let resourceID = registerBuffer("test.audit.inferred", lifetime: .persistent)
        let compiled = try compileRenderGraph([
            "writer": pass("writer", uses: [.buffer(resourceID, access: .write)]),
            "middle": pass("middle", dependencies: ["writer"]),
            "reader": pass(
                "reader",
                dependencies: ["middle"],
                uses: [.buffer(resourceID, access: .read)]
            ),
        ])

        XCTAssertEqual(
            compiled.optimizationReport.redundantDependencies,
            [
                CompiledRenderGraphRedundantDependency(
                    passID: "reader",
                    dependencyID: "writer",
                    inferred: true
                ),
            ]
        )
    }

    func testReportListsUnusedDeclarationsWithoutRemovingThem() throws {
        let used = registerBuffer("test.audit.used", lifetime: .persistent)
        let unused = registerBuffer("test.audit.unused", lifetime: .transient)
        let compiled = try compileRenderGraph([
            "pass": pass("pass", uses: [.buffer(used, access: .write)]),
        ])

        XCTAssertEqual(
            compiled.optimizationReport.unusedResources,
            [
                RenderGraphResourceDeclarationSnapshot(
                    kind: .buffer,
                    resourceID: unused.rawValue,
                    ownerID: nil,
                    lifetime: .transient
                ),
            ]
        )
        XCTAssertNotNil(RenderResourceRegistry.shared.bufferDeclaration(unused))
    }

    func testValidationRejectsOverlappingAliasPlan() throws {
        let firstID = registerBuffer("test.audit.overlap.first", lifetime: .transient)
        let secondID = registerBuffer("test.audit.overlap.second", lifetime: .transient)
        let compiled = try compileRenderGraph([
            "first": pass("first", uses: [.buffer(firstID, access: .write)]),
            "second": pass(
                "second",
                dependencies: ["first"],
                uses: [.buffer(secondID, access: .write)]
            ),
            "read": pass(
                "read",
                dependencies: ["second"],
                uses: [
                    .buffer(firstID, access: .read),
                    .buffer(secondID, access: .read),
                ]
            ),
        ])
        let resources = compiled.resourcePlan.resources.map { resource in
            CompiledRenderGraphResource(
                kind: resource.kind,
                resourceID: resource.resourceID,
                ownerID: resource.ownerID,
                lifetime: resource.lifetime,
                firstUsePassIndex: resource.firstUsePassIndex,
                lastUsePassIndex: resource.lastUsePassIndex,
                passIDs: resource.passIDs,
                aliasSlotID: 0
            )
        }
        let invalidPlan = CompiledRenderGraphResourcePlan(
            resources: resources,
            transientAliasSlots: [
                CompiledRenderGraphAliasSlot(
                    id: 0,
                    kind: .buffer,
                    ownerID: nil,
                    resourceIDs: [firstID.rawValue, secondID.rawValue]
                ),
            ]
        )

        XCTAssertEqual(
            validateCompiledRenderGraphResourcePlan(
                compiled.orderedPasses,
                resourcePlan: invalidPlan
            ),
            [
                .overlappingAliasSlot(
                    slotID: 0,
                    firstResourceID: firstID.rawValue,
                    secondResourceID: secondID.rawValue
                ),
            ]
        )
    }

    func testOptimizationReportIsDeterministic() throws {
        let resourceID = registerBuffer("test.audit.deterministic", lifetime: .persistent)
        let writer = pass("writer", uses: [.buffer(resourceID, access: .write)])
        let reader = pass(
            "reader",
            dependencies: ["writer"],
            uses: [.buffer(resourceID, access: .read)]
        )
        var forward: [String: RenderPass] = [:]
        var reverse: [String: RenderPass] = [:]
        forward[writer.id] = writer
        forward[reader.id] = reader
        reverse[reader.id] = reader
        reverse[writer.id] = writer

        XCTAssertEqual(
            try compileRenderGraph(forward).optimizationReport,
            try compileRenderGraph(reverse).optimizationReport
        )
    }

    func testOptimizationAuditDoesNotRemovePasses() throws {
        let graph = [
            "root": pass("root"),
            "side-effect": pass("side-effect"),
        ]

        let compiled = try compileRenderGraph(graph)

        XCTAssertEqual(compiled.executionOrder, ["root", "side-effect"])
        XCTAssertEqual(compiled.optimizationReport.statistics.passCount, graph.count)
    }

    private func registerBuffer(
        _ id: String,
        lifetime: RenderExtensionResourceLifetime
    ) -> RenderBufferResourceID {
        let resourceID = RenderBufferResourceID(id)
        RenderResourceRegistry.shared.registerBuffer(
            RenderExtensionBufferDescriptor(
                id: resourceID,
                length: 64,
                lifetime: lifetime
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

final class RenderGraphOptimizationExtensionTest: BaseRenderSetup {
    func testAuditCoversMultipleExtensionContributions() throws {
        let water = OptimizationAuditRenderExtension(id: "test.audit.water")
        let grass = OptimizationAuditRenderExtension(id: "test.audit.grass")
        setRendering(.extensions(.register(water)))
        setRendering(.extensions(.register(grass)))

        let compiled = try buildExecutableGameModeGraph()
        let report = compiled.optimizationReport

        XCTAssertTrue(report.isResourcePlanValid)
        XCTAssertEqual(
            Set(report.unusedResources.map(\.resourceID)),
            Set([water.unusedBufferID.rawValue, grass.unusedBufferID.rawValue])
        )
        let waterResource = try XCTUnwrap(
            compiled.resourcePlan.resource(
                kind: .buffer,
                id: water.usedBufferID.rawValue
            )
        )
        let grassResource = try XCTUnwrap(
            compiled.resourcePlan.resource(
                kind: .buffer,
                id: grass.usedBufferID.rawValue
            )
        )
        XCTAssertNotEqual(waterResource.aliasSlotID, grassResource.aliasSlotID)
        XCTAssertEqual(
            waterResource.ownerID,
            water.id
        )
        XCTAssertEqual(
            grassResource.ownerID,
            grass.id
        )
    }
}

private final class OptimizationAuditRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let usedBufferID: RenderBufferResourceID
    let unusedBufferID: RenderBufferResourceID

    init(id: String) {
        self.id = id
        usedBufferID = RenderBufferResourceID("\(id).used")
        unusedBufferID = RenderBufferResourceID("\(id).unused")
    }

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerBuffer(
            RenderExtensionBufferDescriptor(
                id: usedBufferID,
                length: 64,
                lifetime: .transient
            )
        )
        registry.registerBuffer(
            RenderExtensionBufferDescriptor(id: unusedBufferID, length: 64)
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(
            id: "\(id).pass",
            stage: .beforeOutput,
            resources: [.buffer(usedBufferID, access: .write)],
            execute: nil
        )
    }
}
