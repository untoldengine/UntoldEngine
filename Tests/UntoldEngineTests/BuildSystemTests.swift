//
//  BuildSystemTests.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//

import Foundation
@testable import UntoldEngine
import XCTest

final class BuildSystemTests: XCTestCase {
    var tempDirectory: URL!
    var buildSystem: BuildSystem!
    
    override func setUp() {
        super.setUp()
        buildSystem = BuildSystem.shared
        
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BuildSystemTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        super.tearDown()
        
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    // MARK: - projectExists Tests
    
    func testProjectExistsReturnsTrueWhenProjectExists() {
        // Given: A BuildSettings with a project that exists
        let projectName = "TestProject"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.test.app",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )
        
        // Create the project directory structure
        let projectDir = tempDirectory.appendingPathComponent(projectName)
        let xcodeProjectPath = projectDir.appendingPathComponent("\(projectName).xcodeproj")
        try? FileManager.default.createDirectory(at: xcodeProjectPath, withIntermediateDirectories: true)
        
        // When: Checking if project exists
        let result = buildSystem.projectExists(settings: settings)
        
        // Then: Should return true
        XCTAssertTrue(result, "projectExists should return true when project exists at the specified path")
    }
    
    func testProjectExistsReturnsFalseWhenNoProjectExists() {
        // Given: A BuildSettings with a project that does not exist
        let projectName = "NonExistentProject"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.test.app",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )
        
        // When: Checking if project exists (without creating it)
        let result = buildSystem.projectExists(settings: settings)
        
        // Then: Should return false
        XCTAssertFalse(result, "projectExists should return false when no project exists at the specified path")
    }
    
    // MARK: - isValidProjectStructure Tests
    
    func testIsValidProjectStructureReturnsTrueForValidStructure() {
        // Given: A BuildSettings with a valid project structure
        let projectName = "ValidProject"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.test.app",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )
        
        // Create the expected directory structure
        let projectDir = tempDirectory.appendingPathComponent(projectName)
        let gameDataDir = projectDir
            .appendingPathComponent("Sources")
            .appendingPathComponent(projectName)
            .appendingPathComponent("GameData")
        
        try? FileManager.default.createDirectory(at: gameDataDir, withIntermediateDirectories: true)
        
        // When: Checking if project structure is valid
        let result = buildSystem.isValidProjectStructure(settings: settings)
        
        // Then: Should return true
        XCTAssertTrue(result, "isValidProjectStructure should return true for a valid project structure")
    }
    
    func testIsValidProjectStructureReturnsFalseForInvalidStructure() {
        // Given: A BuildSettings with an invalid project structure (missing GameData directory)
        let projectName = "InvalidProject"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.test.app",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )
        
        // Create project directory but without GameData subdirectory
        let projectDir = tempDirectory.appendingPathComponent(projectName)
        try? FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        
        // When: Checking if project structure is valid
        let result = buildSystem.isValidProjectStructure(settings: settings)
        
        // Then: Should return false
        XCTAssertFalse(result, "isValidProjectStructure should return false for an invalid project structure")
    }
    
    // MARK: - updateGameData Tests
    
    func testUpdateGameDataThrowsProjectNotFoundError() async {
        // Given: A BuildSettings for a project that does not exist
        let projectName = "NonExistentProject"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.test.app",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )
        
        // When/Then: Calling updateGameData should throw projectNotFound error
        do {
            _ = try await buildSystem.updateGameData(settings: settings)
            XCTFail("updateGameData should throw an error when project does not exist")
        } catch let error as BuildError {
            // Verify it's the correct error type
            if case .projectNotFound(let message) = error {
                XCTAssertTrue(message.contains("Project not found"), "Error message should indicate project not found")
            } else {
                XCTFail("Expected projectNotFound error, got \(error)")
            }
        } catch {
            XCTFail("Expected BuildError.projectNotFound, got \(error)")
        }
    }
}
