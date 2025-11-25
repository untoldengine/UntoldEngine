//
//  ScriptComponentSceneIntegrationTest.swift
//  UntoldEngineTests
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import XCTest
@testable import UntoldEngine

final class ScriptComponentSceneIntegrationTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Initialize scripting system to register ScriptComponent
        initScriptingSystem()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func test_scriptComponent_serializesIntoCustomComponents() throws {
        // Create a script
        let script = USCScript(
            name: "TestMovementScript",
            instructions: [
                .log("Initializing movement"),
                .setVariable(name: "speed", value: .float(10.0)),
                .translateBy(entity: "self", position: Vec3(x: 1, y: 0, z: 0))
            ],
            metadata: ScriptMetadata(
                triggerType: .perFrame,
                executionMode: .auto
            )
        )
        
        // Create a ScriptComponent
        let scriptComponent = ScriptComponent()
        scriptComponent.script = script
        scriptComponent.scriptFilePath = "/Assets/Scripts/movement.uscript"
        
        // Encode it (simulating what the scene serializer does)
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(scriptComponent)
        
        // Decode it (simulating what the scene deserializer does)
        let decoder = JSONDecoder()
        let decodedComponent = try decoder.decode(ScriptComponent.self, from: jsonData)
        
        // Verify the decoded component matches what we serialized
        XCTAssertNotNil(decodedComponent.script, "Script should be in decoded component")
        XCTAssertEqual(decodedComponent.script?.name, "TestMovementScript", "Script name should match")
        XCTAssertEqual(decodedComponent.scriptFilePath, "/Assets/Scripts/movement.uscript", "Script path should match")
        XCTAssertEqual(decodedComponent.script?.instructions.count, 3, "Should have 3 instructions")
        XCTAssertEqual(decodedComponent.script?.metadata.triggerType, .perFrame, "Trigger type should match")
        XCTAssertEqual(decodedComponent.script?.metadata.executionMode, .auto, "Execution mode should match")
    }
    
}
