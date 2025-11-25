//
//  ScriptComponentSerializationTest.swift
//  UntoldEngineTests
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import XCTest
@testable import UntoldEngine

final class ScriptComponentSerializationTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Initialize scripting system to register ScriptComponent
        initScriptingSystem()
    }
    
    func test_scriptComponent_canBeEncoded() throws {
        // Create a simple script
        let script = USCScript(
            name: "TestScript",
            instructions: [
                .log("Hello World"),
                .setVariable(name: "speed", value: .float(5.0))
            ],
            metadata: ScriptMetadata(
                triggerType: .perFrame,
                executionMode: .auto
            )
        )
        
        // Create a ScriptComponent
        let scriptComponent = ScriptComponent()
        scriptComponent.script = script
        scriptComponent.scriptFilePath = "/path/to/test.uscript"
        
        // Encode it
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(scriptComponent)
        
        // Verify it encoded
        XCTAssertFalse(jsonData.isEmpty)
        
        // Verify we can see the script name in the JSON
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        print("Encoded JSON:\n\(jsonString ?? "nil")")
        XCTAssertTrue(jsonString!.contains("TestScript"), "JSON should contain TestScript")
        XCTAssertTrue(jsonString!.contains("test.uscript"), "JSON should contain test.uscript")
    }
    
    func test_scriptComponent_canBeDecoded() throws {
        // Create a simple script
        let originalScript = USCScript(
            name: "DecodingTest",
            instructions: [
                .translateBy(entity: "player", position: Vec3(x: 1, y: 0, z: 0)),
                .log("Moving player")
            ],
            metadata: ScriptMetadata(
                triggerType: .event,
                executionMode: .interpreted
            )
        )
        
        // Create and encode
        let original = ScriptComponent()
        original.script = originalScript
        original.scriptFilePath = "/scripts/test.uscript"
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(original)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScriptComponent.self, from: jsonData)
        
        // Verify
        XCTAssertEqual(decoded.script?.name, "DecodingTest")
        XCTAssertEqual(decoded.scriptFilePath, "/scripts/test.uscript")
        XCTAssertEqual(decoded.script?.instructions.count, 2)
        XCTAssertEqual(decoded.script?.metadata.triggerType, .event)
        XCTAssertEqual(decoded.script?.metadata.executionMode, .interpreted)
    }
    
    func test_scriptComponent_withNilValues_canBeEncoded() throws {
        // Create empty ScriptComponent
        let scriptComponent = ScriptComponent()
        
        // Encode it
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(scriptComponent)
        
        // Verify it encoded
        XCTAssertFalse(jsonData.isEmpty)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScriptComponent.self, from: jsonData)
        
        // Verify nil values are preserved
        XCTAssertNil(decoded.script)
        XCTAssertNil(decoded.scriptFilePath)
    }
}
