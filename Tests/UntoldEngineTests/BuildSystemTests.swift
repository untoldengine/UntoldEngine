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
        if let tempDirectory {
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
            if case let .projectNotFound(message) = error {
                XCTAssertTrue(message.contains("Project not found"), "Error message should indicate project not found")
            } else {
                XCTFail("Expected projectNotFound error, got \(error)")
            }
        } catch {
            XCTFail("Expected BuildError.projectNotFound, got \(error)")
        }
    }

    // MARK: - Template Generation Tests

    func testAppDelegateSwiftGeneratedWithExpectedContent() throws {
        // Given: Build settings for a project
        let projectName = "MyGameProject"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.test.game",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )

        // When: Getting template files
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: AppDelegate.swift should exist in templates
        let appDelegateKey = "Sources/{{PROJECT_NAME}}/AppDelegate.swift"
        XCTAssertNotNil(templateFiles[appDelegateKey], "AppDelegate.swift template should exist")

        guard let appDelegateContent = templateFiles[appDelegateKey] else {
            XCTFail("AppDelegate.swift content should not be nil")
            return
        }

        // Verify expected content
        XCTAssertTrue(appDelegateContent.contains("class AppDelegate: NSObject, NSApplicationDelegate"),
                      "AppDelegate.swift should contain the AppDelegate class declaration")
        XCTAssertTrue(appDelegateContent.contains("@main"),
                      "AppDelegate.swift should contain @main attribute")
        XCTAssertTrue(appDelegateContent.contains("func applicationDidFinishLaunching(_ aNotification: Notification)"),
                      "AppDelegate.swift should contain applicationDidFinishLaunching method")
        XCTAssertTrue(appDelegateContent.contains("func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool"),
                      "AppDelegate.swift should contain applicationShouldTerminateAfterLastWindowClosed method")
        XCTAssertTrue(appDelegateContent.contains("{{PROJECT_NAME}}"),
                      "AppDelegate.swift should contain project name placeholder")
        XCTAssertTrue(appDelegateContent.contains("import Cocoa"),
                      "AppDelegate.swift should import Cocoa")
    }

    func testGameViewControllerSwiftGeneratedWithExpectedContent() throws {
        // Given: Build settings for a project
        let projectName = "MyGameProject"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.test.game",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )

        // When: Getting template files
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: GameViewController.swift should exist in templates
        let gameViewControllerKey = "Sources/{{PROJECT_NAME}}/GameViewController.swift"
        XCTAssertNotNil(templateFiles[gameViewControllerKey], "GameViewController.swift template should exist")

        guard let gameViewControllerContent = templateFiles[gameViewControllerKey] else {
            XCTFail("GameViewController.swift content should not be nil")
            return
        }

        // Verify expected content
        XCTAssertTrue(gameViewControllerContent.contains("class GameScene"),
                      "GameViewController.swift should contain GameScene class")
        XCTAssertTrue(gameViewControllerContent.contains("class GameViewController: NSViewController"),
                      "GameViewController.swift should contain GameViewController class")
        XCTAssertTrue(gameViewControllerContent.contains("import UntoldEngine"),
                      "GameViewController.swift should import UntoldEngine")
        XCTAssertTrue(gameViewControllerContent.contains("import MetalKit"),
                      "GameViewController.swift should import MetalKit")
        XCTAssertTrue(gameViewControllerContent.contains("var renderer: UntoldRenderer!"),
                      "GameViewController.swift should declare renderer property")
        XCTAssertTrue(gameViewControllerContent.contains("assetBasePath"),
                      "GameViewController.swift should set assetBasePath")
        XCTAssertTrue(gameViewControllerContent.contains("loadBundledScripts()"),
                      "GameViewController.swift should call loadBundledScripts")
        XCTAssertTrue(gameViewControllerContent.contains("playSceneAt(url: sceneURL)"),
                      "GameViewController.swift should call playSceneAt")
        XCTAssertTrue(gameViewControllerContent.contains("func update(deltaTime"),
                      "GameViewController.swift should contain update method")
    }

    func testMainStoryboardGeneratedCorrectly() throws {
        // Given: Build settings for a project
        let projectName = "MyGameProject"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.test.game",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )

        // When: Getting template files
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: Main.storyboard should exist in templates
        let storyboardKey = "Sources/{{PROJECT_NAME}}/Base.lproj/Main.storyboard"
        XCTAssertNotNil(templateFiles[storyboardKey], "Main.storyboard template should exist")

        guard let storyboardContent = templateFiles[storyboardKey] else {
            XCTFail("Main.storyboard content should not be nil")
            return
        }

        // Verify expected content
        XCTAssertTrue(storyboardContent.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"),
                      "Main.storyboard should contain XML declaration")
        XCTAssertTrue(storyboardContent.contains("<document type=\"com.apple.InterfaceBuilder3.Cocoa.Storyboard.XIB\""),
                      "Main.storyboard should contain storyboard document type")
        XCTAssertTrue(storyboardContent.contains("customClass=\"AppDelegate\""),
                      "Main.storyboard should reference AppDelegate")
        XCTAssertTrue(storyboardContent.contains("customClass=\"GameViewController\""),
                      "Main.storyboard should reference GameViewController")
        XCTAssertTrue(storyboardContent.contains("customClass=\"MTKView\""),
                      "Main.storyboard should contain MTKView")
        XCTAssertTrue(storyboardContent.contains("{{PROJECT_NAME}}"),
                      "Main.storyboard should contain project name placeholder")
    }

    func testInfoPlistGeneratedWithCorrectBundleIdentifier() throws {
        // Given: Build settings for a project
        let projectName = "MyGameProject"
        let bundleID = "com.mycompany.mygame"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: bundleID,
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )

        // When: Getting template files
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: Info.plist should exist in templates
        let infoPlistKey = "Sources/{{PROJECT_NAME}}/Info.plist"
        XCTAssertNotNil(templateFiles[infoPlistKey], "Info.plist template should exist")

        guard let infoPlistContent = templateFiles[infoPlistKey] else {
            XCTFail("Info.plist content should not be nil")
            return
        }

        // Verify expected content
        XCTAssertTrue(infoPlistContent.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"),
                      "Info.plist should contain XML declaration")
        XCTAssertTrue(infoPlistContent.contains("<!DOCTYPE plist PUBLIC"),
                      "Info.plist should contain plist DOCTYPE")
        XCTAssertTrue(infoPlistContent.contains("<key>CFBundleIdentifier</key>"),
                      "Info.plist should contain CFBundleIdentifier key")
        XCTAssertTrue(infoPlistContent.contains("<string>{{BUNDLE_IDENTIFIER}}</string>"),
                      "Info.plist should contain bundle identifier placeholder")
        XCTAssertTrue(infoPlistContent.contains("<key>CFBundleExecutable</key>"),
                      "Info.plist should contain CFBundleExecutable key")
        XCTAssertTrue(infoPlistContent.contains("<key>NSMainStoryboardFile</key>"),
                      "Info.plist should contain NSMainStoryboardFile key")
        XCTAssertTrue(infoPlistContent.contains("<string>Main</string>"),
                      "Info.plist should reference Main storyboard")
        XCTAssertTrue(infoPlistContent.contains("<key>LSApplicationCategoryType</key>"),
                      "Info.plist should contain application category")
        XCTAssertTrue(infoPlistContent.contains("<string>public.app-category.games</string>"),
                      "Info.plist should be categorized as games")
    }

    func testXcodeProjectSpecIncludesBaseLprojAndInfoPlist() throws {
        // Given: Build settings for a project
        let projectName = "MyGameProject"
        let bundleID = "com.mycompany.mygame"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: bundleID,
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )

        // When: Generating XcodeGen YAML spec
        let yamlContent = try XcodeGenProjectSpec.generateYAML(settings: settings)

        // Then: Verify the YAML includes Base.lproj as a resource
        XCTAssertTrue(yamlContent.contains("path: Sources/\(projectName)/Base.lproj"),
                      "XcodeGen spec should include Base.lproj path")
        XCTAssertTrue(yamlContent.contains("type: folder"),
                      "XcodeGen spec should specify folder type for resources")
        XCTAssertTrue(yamlContent.contains("buildPhase: resources"),
                      "XcodeGen spec should include buildPhase: resources")

        // Verify the YAML references custom Info.plist
        XCTAssertTrue(yamlContent.contains("INFOPLIST_FILE: Sources/\(projectName)/Info.plist"),
                      "XcodeGen spec should reference custom Info.plist location")

        // Verify bundle identifier is set
        XCTAssertTrue(yamlContent.contains("PRODUCT_BUNDLE_IDENTIFIER: \(bundleID)"),
                      "XcodeGen spec should include bundle identifier")

        // Verify GameData is also included as resources
        XCTAssertTrue(yamlContent.contains("path: Sources/\(projectName)/GameData"),
                      "XcodeGen spec should include GameData path")

        // Verify project structure
        XCTAssertTrue(yamlContent.contains("name: \(projectName)"),
                      "XcodeGen spec should include project name")
        XCTAssertTrue(yamlContent.contains("type: application"),
                      "XcodeGen spec should specify application type")
    }
}
