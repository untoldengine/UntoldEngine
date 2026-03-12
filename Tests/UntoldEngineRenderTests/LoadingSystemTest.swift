//
//  LoadingSystemTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
@testable import UntoldEngine
import XCTest


@MainActor
final class LoadingSystemTest: XCTestCase {
    override func setUp() async throws {
        let bundleURL = Bundle.module.resourceURL
        assetBasePath = bundleURL
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    func assertResourceExists(_ name: String, _ ext: String,
                              structuredSubdir: String? = nil,
                              file: StaticString = #filePath, line: UInt = #line)
    {
        let base = Bundle.module.resourceURL!
        let fm = FileManager.default

        // 1) flat
        let flatPath = base.appendingPathComponent("\(name).\(ext)").path
        if fm.fileExists(atPath: flatPath) { return }

        // 2) structured (if provided)
        if let sub = structuredSubdir {
            let structPath = base.appendingPathComponent(sub)
                .appendingPathComponent("\(name).\(ext)").path
            if fm.fileExists(atPath: structPath) { return }
        }

        // 3) Bundle query (in case of odd packaging)
        let bundle = Bundle(url: Bundle.module.bundleURL)!
        if bundle.url(forResource: name, withExtension: ext, subdirectory: structuredSubdir) != nil { return }
        if bundle.url(forResource: name, withExtension: ext) != nil { return }

        XCTFail("❌ Missing resource \(name).\(ext) (flat or under \(structuredSubdir ?? "<none>"))",
                file: file, line: line)
    }

    func test_essentialAssetsExist_anyLayout() {
        assertResourceExists("ball", "usdz", structuredSubdir: "Models/ball")
        assertResourceExists("redplayer", "usdz", structuredSubdir: "Models/redplayer")
        assertResourceExists("stadium", "usdz", structuredSubdir: "Models/stadium")
        assertResourceExists("idle", "usdz", structuredSubdir: "Animations/idle")
        assertResourceExists("running", "usdz", structuredSubdir: "Animations/running")
    }

    func test_engineResolverFindsThem() {
        for (name, ext) in [("ball", "usdz"), ("redplayer", "usdz"), ("stadium", "usdz")] {
            XCTAssertNotNil(getResourceURL(resourceName: name, ext: ext, subName: nil),
                            "Engine failed to locate \(name).\(ext)")
        }
    }

    // MARK: - Script Loading Tests

    func test_loadScripts_withNoScriptsDirectory() {
        // Given: A temporary directory without a Scripts folder
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoScriptsTest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        assetBasePath = tempDir

        // When: Load scripts
        let count = loadScripts()

        // Then: Should return 0 and log warning
        XCTAssertEqual(count, 0, "Should return 0 when Scripts directory doesn't exist")
        XCTAssertTrue(scriptRegistry.isEmpty, "Script registry should be empty")
    }

    func test_loadScripts_withEmptyScriptsDirectory() {
        // Given: A Scripts directory with no files
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmptyScriptsTest-\(UUID().uuidString)", isDirectory: true)
        let scriptsDir = tempDir.appendingPathComponent("Scripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        assetBasePath = tempDir

        // When: Load scripts
        let count = loadScripts()

        // Then: Should return 0
        XCTAssertEqual(count, 0, "Should return 0 for empty Scripts directory")
        XCTAssertTrue(scriptRegistry.isEmpty, "Script registry should be empty")
    }

    func test_loadScripts_withValidScripts() throws {
        // Given: A Scripts directory with valid .uscript files
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ValidScriptsTest-\(UUID().uuidString)", isDirectory: true)
        let scriptsDir = tempDir.appendingPathComponent("Scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create test scripts
        let script1 = USCScript(
            name: "PlayerController",
            instructions: [
                .event("OnUpdate"),
                .log("Player update"),
            ],
            metadata: ScriptMetadata(triggerType: .perFrame, executionMode: .interpreted)
        )

        let script2 = USCScript(
            name: "EnemyAI",
            instructions: [
                .event("OnUpdate"),
                .log("Enemy update"),
            ],
            metadata: ScriptMetadata(triggerType: .perFrame, executionMode: .interpreted)
        )

        // Save scripts to disk
        let script1URL = scriptsDir.appendingPathComponent("PlayerController.uscript")
        let script2URL = scriptsDir.appendingPathComponent("EnemyAI.uscript")
        try saveUSCScript(script1, to: script1URL)
        try saveUSCScript(script2, to: script2URL)

        assetBasePath = tempDir

        // When: Load scripts
        let count = loadScripts()

        // Then: Should load both scripts
        XCTAssertEqual(count, 2, "Should load 2 scripts")
        XCTAssertEqual(scriptRegistry.count, 2, "Script registry should contain 2 scripts")
        XCTAssertNotNil(scriptRegistry["PlayerController"], "PlayerController should be loaded")
        XCTAssertNotNil(scriptRegistry["EnemyAI"], "EnemyAI should be loaded")
    }

    func test_loadScripts_ignoresNonUScriptFiles() throws {
        // Given: Scripts directory with mixed file types
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MixedFilesTest-\(UUID().uuidString)", isDirectory: true)
        let scriptsDir = tempDir.appendingPathComponent("Scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a valid script
        let script = USCScript(
            name: "ValidScript",
            instructions: [.event("OnUpdate")],
            metadata: .default
        )
        let scriptURL = scriptsDir.appendingPathComponent("ValidScript.uscript")
        try saveUSCScript(script, to: scriptURL)

        // Create non-script files
        let txtFile = scriptsDir.appendingPathComponent("readme.txt")
        let jsonFile = scriptsDir.appendingPathComponent("config.json")
        try "Some text".write(to: txtFile, atomically: true, encoding: .utf8)
        try "{}".write(to: jsonFile, atomically: true, encoding: .utf8)

        assetBasePath = tempDir

        // When: Load scripts
        let count = loadScripts()

        // Then: Should only load .uscript files
        XCTAssertEqual(count, 1, "Should load only 1 script")
        XCTAssertEqual(scriptRegistry.count, 1, "Script registry should contain only 1 script")
        XCTAssertNotNil(scriptRegistry["ValidScript"], "ValidScript should be loaded")
    }

    func test_getScript_returnsLoadedScript() throws {
        // Given: A loaded script
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GetScriptTest-\(UUID().uuidString)", isDirectory: true)
        let scriptsDir = tempDir.appendingPathComponent("Scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let script = USCScript(
            name: "TestScript",
            instructions: [.event("OnStart")],
            metadata: .default
        )
        let scriptURL = scriptsDir.appendingPathComponent("TestScript.uscript")
        try saveUSCScript(script, to: scriptURL)

        assetBasePath = tempDir
        loadScripts()

        // When: Get script by name
        let retrieved = getScript(named: "TestScript")

        // Then: Should return the script
        XCTAssertNotNil(retrieved, "Should return the loaded script")
        XCTAssertEqual(retrieved?.name, "TestScript", "Script name should match")
    }

    func test_getScript_returnsNilForMissingScript() {
        // Given: Empty script registry
        scriptRegistry.removeAll()

        // When: Get non-existent script
        let retrieved = getScript(named: "NonExistent")

        // Then: Should return nil
        XCTAssertNil(retrieved, "Should return nil for non-existent script")
    }

    func test_isScriptLoaded_returnsTrueForLoadedScript() throws {
        // Given: A loaded script
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IsLoadedTest-\(UUID().uuidString)", isDirectory: true)
        let scriptsDir = tempDir.appendingPathComponent("Scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let script = USCScript(
            name: "LoadedScript",
            instructions: [.event("OnUpdate")],
            metadata: .default
        )
        let scriptURL = scriptsDir.appendingPathComponent("LoadedScript.uscript")
        try saveUSCScript(script, to: scriptURL)

        assetBasePath = tempDir
        loadScripts()

        // When/Then: Check if script is loaded
        XCTAssertTrue(isScriptLoaded(named: "LoadedScript"), "Should return true for loaded script")
        XCTAssertFalse(isScriptLoaded(named: "NotLoaded"), "Should return false for non-existent script")
    }

    func test_reloadScript_updatesScript() throws {
        // Given: A loaded script
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReloadTest-\(UUID().uuidString)", isDirectory: true)
        let scriptsDir = tempDir.appendingPathComponent("Scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let originalScript = USCScript(
            name: "ReloadableScript",
            instructions: [.event("OnStart")],
            metadata: .default
        )
        let scriptURL = scriptsDir.appendingPathComponent("ReloadableScript.uscript")
        try saveUSCScript(originalScript, to: scriptURL)

        assetBasePath = tempDir
        loadScripts()

        // Verify original
        let original = getScript(named: "ReloadableScript")
        XCTAssertEqual(original?.instructions.count, 1)

        // When: Update script file and reload
        let updatedScript = USCScript(
            name: "ReloadableScript",
            instructions: [
                .event("OnStart"),
                .log("Updated"),
            ],
            metadata: .default
        )
        try saveUSCScript(updatedScript, to: scriptURL)
        let success = reloadScript(named: "ReloadableScript")

        // Then: Script should be updated
        XCTAssertTrue(success, "Reload should succeed")
        let reloaded = getScript(named: "ReloadableScript")
        XCTAssertEqual(reloaded?.instructions.count, 2, "Script should have updated instructions")
    }

    func test_reloadScript_failsForMissingScript() {
        // Given: No asset base path or missing script
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReloadFailTest-\(UUID().uuidString)", isDirectory: true)
        let scriptsDir = tempDir.appendingPathComponent("Scripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        assetBasePath = tempDir

        // When: Try to reload non-existent script
        let success = reloadScript(named: "NonExistent")

        // Then: Should fail
        XCTAssertFalse(success, "Reload should fail for non-existent script")
    }

    func test_loadScripts_withCustomURL() throws {
        // Given: A custom Scripts directory (not using assetBasePath)
        let customDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CustomScriptsTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: customDir) }

        // Create a test script in custom location
        let script = USCScript(
            name: "CustomScript",
            instructions: [
                .event("OnStart"),
                .log("From custom location"),
            ],
            metadata: .default
        )
        let scriptURL = customDir.appendingPathComponent("CustomScript.uscript")
        try saveUSCScript(script, to: scriptURL)

        // When: Load scripts from custom URL (not assetBasePath)
        let count = loadScripts(from: customDir)

        // Then: Should load from custom location
        XCTAssertEqual(count, 1, "Should load 1 script from custom directory")
        XCTAssertNotNil(scriptRegistry["CustomScript"], "CustomScript should be loaded")
    }

    func test_loadScripts_usesAssetBasePathWhenNoURLProvided() throws {
        // Given: Scripts in assetBasePath/Scripts
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DefaultPathTest-\(UUID().uuidString)", isDirectory: true)
        let scriptsDir = tempDir.appendingPathComponent("Scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let script = USCScript(
            name: "DefaultPathScript",
            instructions: [.event("OnUpdate")],
            metadata: .default
        )
        let scriptURL = scriptsDir.appendingPathComponent("DefaultPathScript.uscript")
        try saveUSCScript(script, to: scriptURL)

        assetBasePath = tempDir

        // When: Load scripts without providing URL (should use assetBasePath)
        let count = loadScripts()

        // Then: Should load from assetBasePath/Scripts
        XCTAssertEqual(count, 1, "Should load 1 script from default path")
        XCTAssertNotNil(scriptRegistry["DefaultPathScript"], "DefaultPathScript should be loaded")
    }
}
