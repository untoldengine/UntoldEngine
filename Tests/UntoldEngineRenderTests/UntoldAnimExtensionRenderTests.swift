//
//  UntoldAnimExtensionRenderTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngine
import XCTest

final class UntoldAnimExtensionRenderTests: BaseRenderSetup {
    private var tempRoot: URL!

    override func setUp() async throws {
        try await super.setUp()
        LoadingSystem.shared.resourceURLFn = getResourceURL
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldAnimExtensionRenderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        try await super.tearDown()
    }

    override func initializeAssets() {}

    /// Copies a bundled .untold test fixture to a temp path with a `.untoldanim`
    /// extension, so tests can exercise the new extension without needing a
    /// checked-in duplicate binary fixture.
    private func copyFixture(named name: String, to newName: String) throws -> URL {
        guard let sourceURL = LoadingSystem.shared.resourceURL(forResource: name, withExtension: "untold") else {
            XCTFail("bundled \(name).untold test asset not found")
            throw CocoaError(.fileNoSuchFile)
        }
        let destination = tempRoot.appendingPathComponent(newName).appendingPathExtension("untoldanim")
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    func testSetEntityMeshAsyncRejectsUntoldanim() async throws {
        let untoldanimURL = try copyFixture(named: "ball", to: "ball")

        let entityId = createEntity()
        let expectation = expectation(description: "mesh load completes")
        setEntityMeshAsync(entityId: entityId, filename: untoldanimURL.deletingPathExtension().path, withExtension: "untoldanim") { success in
            XCTAssertFalse(success, "setEntityMeshAsync should reject .untoldanim files")
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testSetEntityAnimationsAcceptsUntoldanim() async throws {
        guard let redplayerURL = LoadingSystem.shared.resourceURL(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("bundled redplayer.untold test asset not found")
            return
        }
        let runningUntoldanimURL = try copyFixture(named: "running", to: "running")

        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "player")
        let meshExpectation = expectation(description: "redplayer loaded")
        setEntityMeshAsync(entityId: entityId, filename: redplayerURL.deletingPathExtension().path, withExtension: "untold") { _ in
            meshExpectation.fulfill()
        }
        await fulfillment(of: [meshExpectation], timeout: 10.0)

        setEntityAnimations(
            entityId: entityId,
            filename: runningUntoldanimURL.deletingPathExtension().path,
            withExtension: "untoldanim",
            name: "running"
        )

        // The skeleton (and so the AnimationComponent) may land on a child entity
        // rather than the root for multi-node assets -- resolve the same way
        // setEntityAnimations itself does rather than assuming it's on entityId.
        let targetEntityIds = resolveAnimationBindingTargetEntities(entityId: entityId)
        guard let animationComponent = targetEntityIds.compactMap({ scene.get(component: AnimationComponent.self, for: $0) }).first else {
            XCTFail("AnimationComponent was not registered after loading a .untoldanim clip")
            return
        }
        XCTAssertNotNil(animationComponent.animationClips["running"], "the .untoldanim clip should have registered under its requested name")
    }
}
