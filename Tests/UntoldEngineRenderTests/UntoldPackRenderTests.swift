//
//  UntoldPackRenderTests.swift
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

final class UntoldPackRenderTests: BaseRenderSetup {
    private var tempRoot: URL!

    override func setUp() async throws {
        try await super.setUp()
        LoadingSystem.shared.resourceURLFn = getResourceURL
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldPackRenderTests-\(UUID().uuidString)", isDirectory: true)
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

    /// Copies the bundled "ball" test asset to `path` under tempRoot so a real .untold
    /// binary backs each pack model, and writes a .untoldpack manifest referencing them.
    private func writePack(models: [(displayName: String, path: String, translationX: Float)]) throws -> URL {
        guard let ballURL = LoadingSystem.shared.resourceURL(forResource: "ball", withExtension: "untold") else {
            XCTFail("bundled ball.untold test asset not found")
            throw CocoaError(.fileNoSuchFile)
        }

        let modelsJSON = models.map { model in
            let destination = tempRoot.appendingPathComponent(model.path)
            try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: ballURL, to: destination)

            return """
            {
              "displayName": "\(model.displayName)",
              "path": "\(model.path)",
              "transform": [
                [1.0, 0.0, 0.0, \(model.translationX)],
                [0.0, 1.0, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0]
              ]
            }
            """
        }.joined(separator: ",\n")

        let json = """
        {
          "formatVersion": 1,
          "sourceAsset": "Robot.blend",
          "models": [\(modelsJSON)]
        }
        """
        let packURL = tempRoot.appendingPathComponent("Robot").appendingPathExtension("untoldpack")
        try Data(json.utf8).write(to: packURL)
        return packURL
    }

    func testSetEntityMeshAsyncRoutesUntoldpackToOneChildEntityPerModelWithTransform() async throws {
        let packURL = try writePack(models: [
            (displayName: "Body", path: "Body/Body.untold", translationX: 0.0),
            (displayName: "Arm", path: "Arm/Arm.untold", translationX: 2.5),
        ])

        let rootId = createEntity()
        let expectation = expectation(description: "pack load completes")
        setEntityMeshAsync(entityId: rootId, filename: packURL.deletingPathExtension().path, withExtension: "untoldpack") { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5.0)

        guard let scenegraph = scene.get(component: ScenegraphComponent.self, for: rootId) else {
            XCTFail("root entity missing ScenegraphComponent")
            return
        }
        XCTAssertEqual(scenegraph.children.count, 2)

        let armId = try XCTUnwrap(scenegraph.children.first { getEntityName(entityId: $0) == "Arm" })
        XCTAssertEqual(getPosition(entityId: armId).x, 2.5, accuracy: 0.0001)
        XCTAssertTrue(hasComponent(entityId: armId, componentType: RenderComponent.self))
    }
}
