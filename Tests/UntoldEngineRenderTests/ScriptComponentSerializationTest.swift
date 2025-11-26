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
        
        // Create a ScriptComponent with multi-script API
        let scriptComponent = ScriptComponent()
        scriptComponent.scripts = [script]
        scriptComponent.scriptFilePaths = ["/path/to/test.uscript"]
        
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
        
        // Decode back to ensure round-trip
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScriptComponent.self, from: jsonData)
        XCTAssertEqual(decoded.scripts.count, 1)
        XCTAssertEqual(decoded.scripts.first?.name, "TestScript")
        XCTAssertEqual(decoded.scriptFilePaths?.first, "/path/to/test.uscript")
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
        
        // Create and encode using new multi-script API
        let original = ScriptComponent()
        original.scripts = [originalScript]
        original.scriptFilePaths = ["/scripts/test.uscript"]
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(original)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScriptComponent.self, from: jsonData)
        
        // Verify
        XCTAssertEqual(decoded.scripts.count, 1)
        XCTAssertEqual(decoded.scripts.first?.name, "DecodingTest")
        XCTAssertEqual(decoded.scriptFilePaths?.first, "/scripts/test.uscript")
        XCTAssertEqual(decoded.scripts.first?.instructions.count, 2)
        XCTAssertEqual(decoded.scripts.first?.metadata.triggerType, .event)
        XCTAssertEqual(decoded.scripts.first?.metadata.executionMode, .interpreted)
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
        
        // Verify empty arrays / nil arrays are preserved
        XCTAssertEqual(decoded.scripts.count, 0)
        XCTAssertNil(decoded.scriptFilePaths)
    }
    
    func test_scriptComponent_legacySingleFields_decodeIntoArrays() throws {
        // Construct legacy JSON that uses single 'script' and 'scriptFilePath'
        let legacyScript = USCScript(
            name: "LegacyScript",
            instructions: [
                .log("legacy")
            ],
            metadata: ScriptMetadata(triggerType: .perFrame, executionMode: .auto)
        )
        
        let legacyComponent = ScriptComponent()
        // Simulate legacy by encoding via a manual container:
        // We’ll encode using the legacy keys to ensure the new decoder maps them to arrays.
        struct LegacyWrapper: Codable {
            let script: USCScript?
            let scriptFilePath: String?
        }
        let legacy = LegacyWrapper(script: legacyScript, scriptFilePath: "/legacy/path.uscript")
        let encoder = JSONEncoder()
        let legacyData = try encoder.encode(legacy)
        
        // Decode using new ScriptComponent decoder (should map into arrays)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScriptComponent.self, from: legacyData)
        
        XCTAssertEqual(decoded.scripts.count, 1)
        XCTAssertEqual(decoded.scripts.first?.name, "LegacyScript")
        XCTAssertEqual(decoded.scriptFilePaths?.first, "/legacy/path.uscript")
    }
}

