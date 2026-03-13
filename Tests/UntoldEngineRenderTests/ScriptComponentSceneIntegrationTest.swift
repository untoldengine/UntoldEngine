//
//  ScriptComponentSceneIntegrationTest.swift
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

@MainActor
final class ScriptComponentSceneIntegrationTest: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        // Initialize scripting system to register ScriptComponent
        initScriptingSystem()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    func test_scriptComponent_serializesIntoCustomComponents() throws {
        // Create a script
        let script = USCScript(
            name: "TestMovementScript",
            instructions: [
                .log("Initializing movement"),
                .setVariable(name: "speed", value: .float(10.0)),
                .translateBy(entity: "self", position: simd_float3(x: 1, y: 0, z: 0)),
            ],
            metadata: ScriptMetadata(
                triggerType: .perFrame,
                executionMode: .auto
            )
        )

        // Create a ScriptComponent using multi-script API
        let scriptComponent = ScriptComponent()
        scriptComponent.scripts = [script]
        scriptComponent.scriptFilePaths = ["/Assets/Scripts/movement.uscript"]

        // Encode it (simulating what the scene serializer does)
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(scriptComponent)

        // Decode it (simulating what the scene deserializer does)
        let decoder = JSONDecoder()
        let decodedComponent = try decoder.decode(ScriptComponent.self, from: jsonData)

        // Verify the decoded component matches what we serialized
        XCTAssertEqual(decodedComponent.scripts.count, 1, "Should have one script")
        XCTAssertEqual(decodedComponent.scripts.first?.name, "TestMovementScript", "Script name should match")
        XCTAssertEqual(decodedComponent.scriptFilePaths?.first, "/Assets/Scripts/movement.uscript", "Script path should match")
        XCTAssertEqual(decodedComponent.scripts.first?.instructions.count, 3, "Should have 3 instructions")
        XCTAssertEqual(decodedComponent.scripts.first?.metadata.triggerType, .perFrame, "Trigger type should match")
        XCTAssertEqual(decodedComponent.scripts.first?.metadata.executionMode, .auto, "Execution mode should match")
    }

    func test_scriptComponent_multipleScripts_roundTrip() throws {
        let scriptA = USCScript(
            name: "A",
            instructions: [.log("A")],
            metadata: .init(triggerType: .perFrame, executionMode: .auto)
        )
        let scriptB = USCScript(
            name: "B",
            instructions: [.log("B")],
            metadata: .init(triggerType: .event, executionMode: .interpreted)
        )

        let component = ScriptComponent()
        component.scripts = [scriptA, scriptB]
        component.scriptFilePaths = ["/A.uscript", "/B.uscript"]

        let encoder = JSONEncoder()
        let json = try encoder.encode(component)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScriptComponent.self, from: json)

        XCTAssertEqual(decoded.scripts.count, 2)
        XCTAssertEqual(decoded.scripts[0].name, "A")
        XCTAssertEqual(decoded.scripts[1].name, "B")
        XCTAssertEqual(decoded.scriptFilePaths?.count, 2)
        XCTAssertEqual(decoded.scriptFilePaths?[0], "/A.uscript")
        XCTAssertEqual(decoded.scriptFilePaths?[1], "/B.uscript")
    }
}
