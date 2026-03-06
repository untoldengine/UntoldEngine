//
//  BuildSystemTests.swift
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

    func testMacOSGameSceneSwiftGeneratedWithExpectedContent() throws {
        // Given: Build settings for a macOS project
        let projectName = "MyGameProject"
        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.test.game",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )

        // When: Getting template files
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: GameScene.swift should exist in templates
        let gameSceneKey = "Sources/{{PROJECT_NAME}}/GameScene.swift"
        XCTAssertNotNil(templateFiles[gameSceneKey], "GameScene.swift template should exist")

        guard let gameSceneContent = templateFiles[gameSceneKey] else {
            XCTFail("GameScene.swift content should not be nil")
            return
        }

        // Verify GameScene content
        XCTAssertTrue(gameSceneContent.contains("class GameScene"),
                      "GameScene.swift should contain GameScene class")
        XCTAssertTrue(gameSceneContent.contains("import UntoldEngine"),
                      "GameScene.swift should import UntoldEngine")
        XCTAssertTrue(gameSceneContent.contains("import Foundation"),
                      "GameScene.swift should import Foundation")
        XCTAssertTrue(gameSceneContent.contains("assetBasePath"),
                      "GameScene.swift should set assetBasePath")
        XCTAssertTrue(gameSceneContent.contains("loadBundledScripts()"),
                      "GameScene.swift should call loadBundledScripts")
        XCTAssertTrue(gameSceneContent.contains("playSceneAt(url: sceneURL)"),
                      "GameScene.swift should call playSceneAt")
        XCTAssertTrue(gameSceneContent.contains("func update(deltaTime"),
                      "GameScene.swift should contain update method")
        XCTAssertTrue(gameSceneContent.contains("func handleInput()"),
                      "GameScene.swift should contain handleInput method")
    }

    func testMacOSGameViewControllerSwiftGeneratedWithExpectedContent() throws {
        // Given: Build settings for a macOS project
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

        // Verify GameViewController content (should NOT contain GameScene)
        XCTAssertFalse(gameViewControllerContent.contains("class GameScene"),
                       "GameViewController.swift should NOT contain GameScene class (it's in separate file)")
        XCTAssertTrue(gameViewControllerContent.contains("class GameViewController: NSViewController"),
                      "GameViewController.swift should contain GameViewController class")
        XCTAssertTrue(gameViewControllerContent.contains("import UntoldEngine"),
                      "GameViewController.swift should import UntoldEngine")
        XCTAssertTrue(gameViewControllerContent.contains("import MetalKit"),
                      "GameViewController.swift should import MetalKit")
        XCTAssertTrue(gameViewControllerContent.contains("var renderer: UntoldRenderer!"),
                      "GameViewController.swift should declare renderer property")
        XCTAssertTrue(gameViewControllerContent.contains("var gameScene: GameScene!"),
                      "GameViewController.swift should declare gameScene property")
        XCTAssertTrue(gameViewControllerContent.contains("gameScene = GameScene()"),
                      "GameViewController.swift should initialize GameScene")
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

    // MARK: - iOS Template Tests

    func testIOSAppDelegateSwiftGeneratedWithExpectedContent() throws {
        // Given: Build settings for an iOS project
        let settings = BuildSettings(
            projectName: "MyiOSGame",
            bundleIdentifier: "com.test.iosgame",
            outputPath: tempDirectory,
            target: .iOS(deployment: .v17)
        )

        // When: Getting template files for iOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: iOS AppDelegate.swift should exist
        let appDelegateKey = "Sources/{{PROJECT_NAME}}/AppDelegate.swift"
        XCTAssertNotNil(templateFiles[appDelegateKey], "iOS AppDelegate.swift template should exist")

        guard let appDelegateContent = templateFiles[appDelegateKey] else {
            XCTFail("iOS AppDelegate.swift content should not be nil")
            return
        }

        // Verify iOS-specific content
        XCTAssertTrue(appDelegateContent.contains("import UIKit"),
                      "iOS AppDelegate should import UIKit")
        XCTAssertTrue(appDelegateContent.contains("class AppDelegate: UIResponder, UIApplicationDelegate"),
                      "iOS AppDelegate should extend UIResponder and UIApplicationDelegate")
        XCTAssertTrue(appDelegateContent.contains("func application(_ application: UIApplication, didFinishLaunchingWithOptions"),
                      "iOS AppDelegate should have didFinishLaunchingWithOptions")
        XCTAssertTrue(appDelegateContent.contains("func applicationWillResignActive"),
                      "iOS AppDelegate should have lifecycle methods")
    }

    func testIOSGameSceneSwiftGeneratedWithExpectedContent() throws {
        // Given: Build settings for an iOS project
        let settings = BuildSettings(
            projectName: "MyiOSGame",
            bundleIdentifier: "com.test.iosgame",
            outputPath: tempDirectory,
            target: .iOS(deployment: .v17)
        )

        // When: Getting template files for iOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: iOS GameScene.swift should exist
        let gameSceneKey = "Sources/{{PROJECT_NAME}}/GameScene.swift"
        XCTAssertNotNil(templateFiles[gameSceneKey], "iOS GameScene.swift should exist")

        guard let gameSceneContent = templateFiles[gameSceneKey] else {
            XCTFail("iOS GameScene.swift content should not be nil")
            return
        }

        // Verify GameScene content
        XCTAssertTrue(gameSceneContent.contains("class GameScene"),
                      "iOS GameScene.swift should contain GameScene class")
        XCTAssertTrue(gameSceneContent.contains("import UntoldEngine"),
                      "iOS GameScene.swift should import UntoldEngine")
        XCTAssertTrue(gameSceneContent.contains("import Foundation"),
                      "iOS GameScene.swift should import Foundation")
        XCTAssertTrue(gameSceneContent.contains("assetBasePath"),
                      "iOS GameScene.swift should set assetBasePath")
        XCTAssertTrue(gameSceneContent.contains("loadBundledScripts()"),
                      "iOS GameScene.swift should call loadBundledScripts")
        XCTAssertTrue(gameSceneContent.contains("func update(deltaTime"),
                      "iOS GameScene.swift should contain update method")
        XCTAssertTrue(gameSceneContent.contains("func handleInput()"),
                      "iOS GameScene.swift should contain handleInput method")
    }

    func testIOSGameViewControllerSwiftGeneratedWithExpectedContent() throws {
        // Given: Build settings for an iOS project
        let settings = BuildSettings(
            projectName: "MyiOSGame",
            bundleIdentifier: "com.test.iosgame",
            outputPath: tempDirectory,
            target: .iOS(deployment: .v17)
        )

        // When: Getting template files for iOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: iOS GameViewController.swift should exist
        let gameViewControllerKey = "Sources/{{PROJECT_NAME}}/GameViewController.swift"
        XCTAssertNotNil(templateFiles[gameViewControllerKey], "iOS GameViewController.swift should exist")

        guard let gameViewControllerContent = templateFiles[gameViewControllerKey] else {
            XCTFail("iOS GameViewController.swift content should not be nil")
            return
        }

        // Verify iOS-specific content (should NOT contain GameScene)
        XCTAssertFalse(gameViewControllerContent.contains("class GameScene"),
                       "iOS GameViewController should NOT contain GameScene class (it's in separate file)")
        XCTAssertTrue(gameViewControllerContent.contains("import UIKit"),
                      "iOS GameViewController should import UIKit")
        XCTAssertTrue(gameViewControllerContent.contains("class GameViewController: UIViewController"),
                      "iOS GameViewController should extend UIViewController")
        XCTAssertTrue(gameViewControllerContent.contains("UntoldRenderer.createiOS"),
                      "iOS GameViewController should use createiOS method")
        XCTAssertTrue(gameViewControllerContent.contains("var gameScene: GameScene!"),
                      "iOS GameViewController should declare gameScene property")
        XCTAssertTrue(gameViewControllerContent.contains("gameScene = GameScene()"),
                      "iOS GameViewController should initialize GameScene")
        XCTAssertTrue(gameViewControllerContent.contains("prefersStatusBarHidden"),
                      "iOS GameViewController should hide status bar")
        XCTAssertTrue(gameViewControllerContent.contains("supportedInterfaceOrientations"),
                      "iOS GameViewController should define interface orientations")
        XCTAssertTrue(gameViewControllerContent.contains(".landscape"),
                      "iOS GameViewController should support landscape orientation")
    }

    func testIOSARGameViewControllerSwiftGeneratedWithExpectedContent() throws {
        // When: Getting template files for iOS AR
        let templateFiles = BuildTemplates.getTemplateFilesForIOSAR()

        // Then: iOS AR GameViewController.swift should exist
        let gameViewControllerKey = "Sources/{{PROJECT_NAME}}/GameViewController.swift"
        XCTAssertNotNil(templateFiles[gameViewControllerKey], "iOS AR GameViewController.swift should exist")

        guard let gameViewControllerContent = templateFiles[gameViewControllerKey] else {
            XCTFail("iOS AR GameViewController.swift content should not be nil")
            return
        }

        // Verify iOS AR-specific content
        XCTAssertTrue(gameViewControllerContent.contains("import ARKit"),
                      "iOS AR GameViewController should import ARKit")
        XCTAssertTrue(gameViewControllerContent.contains("ARSessionDelegate"),
                      "iOS AR GameViewController should implement ARSessionDelegate")
        XCTAssertTrue(gameViewControllerContent.contains("import UntoldEngineAR"),
                      "iOS AR GameViewController should import UntoldEngineAR")
        XCTAssertFalse(gameViewControllerContent.contains("import UntoldEngine\n"),
                       "iOS AR GameViewController should NOT import UntoldEngine standalone (it's in GameScene)")
        XCTAssertTrue(gameViewControllerContent.contains("UntoldEngineAR"),
                      "iOS AR GameViewController should use UntoldEngineAR class")
        XCTAssertTrue(gameViewControllerContent.contains("var arSession: ARSession!"),
                      "iOS AR GameViewController should have arSession property")
        XCTAssertTrue(gameViewControllerContent.contains("arSession = ARSession()"),
                      "iOS AR GameViewController should create AR session")
        XCTAssertTrue(gameViewControllerContent.contains("ARWorldTrackingConfiguration"),
                      "iOS AR GameViewController should use ARWorldTrackingConfiguration")
        XCTAssertTrue(gameViewControllerContent.contains("planeDetection"),
                      "iOS AR GameViewController should enable plane detection")
        XCTAssertFalse(gameViewControllerContent.contains("class GameScene"),
                       "iOS AR GameViewController should NOT contain GameScene class (it's in separate file)")
    }

    func testIOSMainStoryboardGeneratedCorrectly() throws {
        // Given: Build settings for an iOS project
        let settings = BuildSettings(
            projectName: "MyiOSGame",
            bundleIdentifier: "com.test.iosgame",
            outputPath: tempDirectory,
            target: .iOS(deployment: .v17)
        )

        // When: Getting template files for iOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: iOS Main.storyboard should exist
        let storyboardKey = "Sources/{{PROJECT_NAME}}/Base.lproj/Main.storyboard"
        XCTAssertNotNil(templateFiles[storyboardKey], "iOS Main.storyboard should exist")

        guard let storyboardContent = templateFiles[storyboardKey] else {
            XCTFail("iOS Main.storyboard content should not be nil")
            return
        }

        // Verify iOS-specific storyboard content
        XCTAssertTrue(storyboardContent.contains("com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB"),
                      "iOS storyboard should be CocoaTouch type")
        XCTAssertTrue(storyboardContent.contains("targetRuntime=\"iOS.CocoaTouch\""),
                      "iOS storyboard should target iOS CocoaTouch runtime")
        XCTAssertTrue(storyboardContent.contains("customClass=\"GameViewController\""),
                      "iOS storyboard should reference GameViewController")
        XCTAssertTrue(storyboardContent.contains("customClass=\"MTKView\""),
                      "iOS storyboard should use MTKView")
    }

    func testIOSInfoPlistContainsRequiredKeys() throws {
        // Given: Build settings for an iOS project
        let settings = BuildSettings(
            projectName: "MyiOSGame",
            bundleIdentifier: "com.test.iosgame",
            outputPath: tempDirectory,
            target: .iOS(deployment: .v17)
        )

        // When: Getting template files for iOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: iOS Info.plist should exist
        let infoPlistKey = "Sources/{{PROJECT_NAME}}/Info.plist"
        XCTAssertNotNil(templateFiles[infoPlistKey], "iOS Info.plist should exist")

        guard let infoPlistContent = templateFiles[infoPlistKey] else {
            XCTFail("iOS Info.plist content should not be nil")
            return
        }

        // Verify iOS-specific Info.plist keys
        XCTAssertTrue(infoPlistContent.contains("<key>LSRequiresIPhoneOS</key>"),
                      "iOS Info.plist should contain LSRequiresIPhoneOS")
        XCTAssertTrue(infoPlistContent.contains("<key>UIRequiredDeviceCapabilities</key>"),
                      "iOS Info.plist should contain UIRequiredDeviceCapabilities")
        XCTAssertTrue(infoPlistContent.contains("<string>metal</string>"),
                      "iOS Info.plist should require Metal capability")
        XCTAssertTrue(infoPlistContent.contains("<key>UIMainStoryboardFile</key>"),
                      "iOS Info.plist should reference main storyboard")
        XCTAssertTrue(infoPlistContent.contains("<key>UIStatusBarHidden</key>"),
                      "iOS Info.plist should configure status bar")
        XCTAssertTrue(infoPlistContent.contains("<key>UISupportedInterfaceOrientations</key>"),
                      "iOS Info.plist should define supported orientations")
        XCTAssertTrue(infoPlistContent.contains("UIInterfaceOrientationLandscapeLeft"),
                      "iOS Info.plist should support landscape orientations")

        // Verify bundle identifier uses build setting substitution
        XCTAssertTrue(infoPlistContent.contains("$(PRODUCT_BUNDLE_IDENTIFIER)"),
                      "iOS Info.plist should use $(PRODUCT_BUNDLE_IDENTIFIER) for CFBundleIdentifier")
        XCTAssertFalse(infoPlistContent.contains("{{BUNDLE_IDENTIFIER}}"),
                       "iOS Info.plist should not contain placeholder {{BUNDLE_IDENTIFIER}}")
    }

    func testIOSARInfoPlistContainsARPermissions() throws {
        // When: Getting template files for iOS AR
        let templateFiles = BuildTemplates.getTemplateFilesForIOSAR()

        // Then: iOS AR Info.plist should exist
        let infoPlistKey = "Sources/{{PROJECT_NAME}}/Info.plist"
        XCTAssertNotNil(templateFiles[infoPlistKey], "iOS AR Info.plist should exist")

        guard let infoPlistContent = templateFiles[infoPlistKey] else {
            XCTFail("iOS AR Info.plist content should not be nil")
            return
        }

        // Verify AR-specific permissions and capabilities
        XCTAssertTrue(infoPlistContent.contains("<key>NSCameraUsageDescription</key>"),
                      "iOS AR Info.plist should contain camera usage description")
        XCTAssertTrue(infoPlistContent.contains("camera access for AR features"),
                      "iOS AR Info.plist should explain camera usage")
        XCTAssertTrue(infoPlistContent.contains("<string>arkit</string>"),
                      "iOS AR Info.plist should require ARKit capability")
        XCTAssertTrue(infoPlistContent.contains("<string>metal</string>"),
                      "iOS AR Info.plist should require Metal capability")

        // Verify bundle identifier uses build setting substitution
        XCTAssertTrue(infoPlistContent.contains("$(PRODUCT_BUNDLE_IDENTIFIER)"),
                      "iOS AR Info.plist should use $(PRODUCT_BUNDLE_IDENTIFIER) for CFBundleIdentifier")
    }

    func testIOSTemplateDoesNotIncludePackageSwift() throws {
        // Given: Build settings for an iOS project
        let settings = BuildSettings(
            projectName: "MyiOSGame",
            bundleIdentifier: "com.test.iosgame",
            outputPath: tempDirectory,
            target: .iOS(deployment: .v17)
        )

        // When: Getting template files for iOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: Package.swift should NOT be in the template files
        XCTAssertNil(templateFiles["Package.swift"],
                     "iOS template should not include Package.swift")

        // Verify other expected files are present
        XCTAssertNotNil(templateFiles["README.md"], "iOS template should include README.md")
        XCTAssertNotNil(templateFiles["Sources/{{PROJECT_NAME}}/AppDelegate.swift"],
                        "iOS template should include AppDelegate.swift")
    }

    func testIOSARTemplateDoesNotIncludePackageSwift() throws {
        // When: Getting template files for iOS AR
        let templateFiles = BuildTemplates.getTemplateFilesForIOSAR()

        // Then: Package.swift should NOT be in the template files
        XCTAssertNil(templateFiles["Package.swift"],
                     "iOS AR template should not include Package.swift")

        // Verify other expected files are present
        XCTAssertNotNil(templateFiles["README.md"], "iOS AR template should include README.md")
        XCTAssertNotNil(templateFiles["Sources/{{PROJECT_NAME}}/AppDelegate.swift"],
                        "iOS AR template should include AppDelegate.swift")
        XCTAssertNotNil(templateFiles["Sources/{{PROJECT_NAME}}/GameScene.swift"],
                        "iOS AR template should include separate GameScene.swift file")
    }

    func testIOSARGameSceneSwiftSeparateFile() throws {
        // When: Getting template files for iOS AR
        let templateFiles = BuildTemplates.getTemplateFilesForIOSAR()

        // Then: GameScene.swift should exist
        let gameSceneKey = "Sources/{{PROJECT_NAME}}/GameScene.swift"
        XCTAssertNotNil(templateFiles[gameSceneKey], "iOS AR GameScene.swift should exist")

        guard let gameSceneContent = templateFiles[gameSceneKey] else {
            XCTFail("iOS AR GameScene.swift content should not be nil")
            return
        }

        // Verify GameScene.swift content
        XCTAssertTrue(gameSceneContent.contains("import Foundation"),
                      "iOS AR GameScene should import Foundation")
        XCTAssertTrue(gameSceneContent.contains("import UntoldEngine"),
                      "iOS AR GameScene should import UntoldEngine")
        XCTAssertTrue(gameSceneContent.contains("class GameScene"),
                      "iOS AR GameScene should contain GameScene class")
        XCTAssertTrue(gameSceneContent.contains("func update(deltaTime"),
                      "iOS AR GameScene should have update method")
        XCTAssertTrue(gameSceneContent.contains("func handleInput()"),
                      "iOS AR GameScene should have handleInput method")
        XCTAssertFalse(gameSceneContent.contains("import UIKit"),
                       "iOS AR GameScene should NOT import UIKit")
        XCTAssertFalse(gameSceneContent.contains("import ARKit"),
                       "iOS AR GameScene should NOT import ARKit")
        XCTAssertFalse(gameSceneContent.contains("import UntoldEngineAR"),
                       "iOS AR GameScene should NOT import UntoldEngineAR")
    }

    // MARK: - visionOS Template Tests

    func testVisionOSAppSwiftGeneratedWithExpectedContent() throws {
        // Given: Build settings for a visionOS project
        let settings = BuildSettings(
            projectName: "MyVisionGame",
            bundleIdentifier: "com.test.visiongame",
            outputPath: tempDirectory,
            target: .visionOS(deployment: .v2)
        )

        // When: Getting template files for visionOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: visionOS App.swift should exist
        let appSwiftKey = "Sources/{{PROJECT_NAME}}/{{PROJECT_NAME}}App.swift"
        XCTAssertNotNil(templateFiles[appSwiftKey], "visionOS App.swift should exist")

        guard let appSwiftContent = templateFiles[appSwiftKey] else {
            XCTFail("visionOS App.swift content should not be nil")
            return
        }

        // Verify visionOS-specific content
        XCTAssertTrue(appSwiftContent.contains("import SwiftUI"),
                      "visionOS App should import SwiftUI")
        XCTAssertTrue(appSwiftContent.contains("import CompositorServices"),
                      "visionOS App should import CompositorServices")
        XCTAssertTrue(appSwiftContent.contains("import UntoldEngineXR"),
                      "visionOS App should import UntoldEngineXR")
        // Check that it doesn't import UntoldEngine as a standalone import (not as part of UntoldEngineXR)
        XCTAssertFalse(appSwiftContent.contains("import UntoldEngine\n"),
                       "visionOS App should NOT import UntoldEngine standalone (it's in GameScene)")
        XCTAssertTrue(appSwiftContent.contains("UntoldEngineXR"),
                      "visionOS App should use UntoldEngineXR class")
        XCTAssertTrue(appSwiftContent.contains("CompositorLayer"),
                      "visionOS App should use CompositorLayer")
        XCTAssertTrue(appSwiftContent.contains("ImmersiveSpace"),
                      "visionOS App should define ImmersiveSpace")
        XCTAssertTrue(appSwiftContent.contains("setImmersionMode(xrImmersionMode: .mixed)"),
                      "visionOS App should set mixed immersion mode")
        XCTAssertTrue(appSwiftContent.contains("XRHolder"),
                      "visionOS App should use XRHolder pattern")
        XCTAssertFalse(appSwiftContent.contains("class GameScene"),
                       "visionOS App should NOT contain GameScene class (it's in separate file)")
    }

    func testVisionOSInfoPlistContainsRequiredKeys() throws {
        // Given: Build settings for a visionOS project
        let settings = BuildSettings(
            projectName: "MyVisionGame",
            bundleIdentifier: "com.test.visiongame",
            outputPath: tempDirectory,
            target: .visionOS(deployment: .v2)
        )

        // When: Getting template files for visionOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: visionOS Info.plist should exist
        let infoPlistKey = "Sources/{{PROJECT_NAME}}/Info.plist"
        XCTAssertNotNil(templateFiles[infoPlistKey], "visionOS Info.plist should exist")

        guard let infoPlistContent = templateFiles[infoPlistKey] else {
            XCTFail("visionOS Info.plist content should not be nil")
            return
        }

        // Verify visionOS-specific Info.plist keys
        XCTAssertTrue(infoPlistContent.contains("<key>UIRequiredDeviceCapabilities</key>"),
                      "visionOS Info.plist should contain UIRequiredDeviceCapabilities")
        XCTAssertTrue(infoPlistContent.contains("<string>metal</string>"),
                      "visionOS Info.plist should require Metal capability")
        XCTAssertTrue(infoPlistContent.contains("<key>NSWorldSensingUsageDescription</key>"),
                      "visionOS Info.plist should contain world sensing usage description")
        XCTAssertTrue(infoPlistContent.contains("immersive AR experiences"),
                      "visionOS Info.plist should explain world sensing usage")

        // Verify bundle identifier uses build setting substitution
        XCTAssertTrue(infoPlistContent.contains("$(PRODUCT_BUNDLE_IDENTIFIER)"),
                      "visionOS Info.plist should use $(PRODUCT_BUNDLE_IDENTIFIER) for CFBundleIdentifier")
    }

    func testVisionOSTemplateDoesNotIncludePackageSwift() throws {
        // Given: Build settings for a visionOS project
        let settings = BuildSettings(
            projectName: "MyVisionGame",
            bundleIdentifier: "com.test.visiongame",
            outputPath: tempDirectory,
            target: .visionOS(deployment: .v2)
        )

        // When: Getting template files for visionOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: Package.swift should NOT be in the template files (visionOS uses Xcode projects)
        XCTAssertNil(templateFiles["Package.swift"],
                     "visionOS template should not include Package.swift")

        // Verify other expected files are present
        XCTAssertNotNil(templateFiles["README.md"], "visionOS template should include README.md")
        XCTAssertNotNil(templateFiles["Sources/{{PROJECT_NAME}}/{{PROJECT_NAME}}App.swift"],
                        "visionOS template should include App.swift")
    }

    func testVisionOSTemplateUsesSwiftUINotAppDelegate() throws {
        // Given: Build settings for a visionOS project
        let settings = BuildSettings(
            projectName: "MyVisionGame",
            bundleIdentifier: "com.test.visiongame",
            outputPath: tempDirectory,
            target: .visionOS(deployment: .v2)
        )

        // When: Getting template files for visionOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: Should not include AppDelegate or GameViewController (uses SwiftUI App)
        XCTAssertNil(templateFiles["Sources/{{PROJECT_NAME}}/AppDelegate.swift"],
                     "visionOS template should not use AppDelegate")
        XCTAssertNil(templateFiles["Sources/{{PROJECT_NAME}}/GameViewController.swift"],
                     "visionOS template should not use GameViewController")

        // Should have the SwiftUI App file and separate GameScene file
        XCTAssertNotNil(templateFiles["Sources/{{PROJECT_NAME}}/{{PROJECT_NAME}}App.swift"],
                        "visionOS template should include SwiftUI App file")
        XCTAssertNotNil(templateFiles["Sources/{{PROJECT_NAME}}/GameScene.swift"],
                        "visionOS template should include separate GameScene.swift file")
    }

    func testVisionOSGameSceneSwiftSeparateFile() throws {
        // Given: Build settings for a visionOS project
        let settings = BuildSettings(
            projectName: "MyVisionGame",
            bundleIdentifier: "com.test.visiongame",
            outputPath: tempDirectory,
            target: .visionOS(deployment: .v2)
        )

        // When: Getting template files for visionOS
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: GameScene.swift should exist
        let gameSceneKey = "Sources/{{PROJECT_NAME}}/GameScene.swift"
        XCTAssertNotNil(templateFiles[gameSceneKey], "visionOS GameScene.swift should exist")

        guard let gameSceneContent = templateFiles[gameSceneKey] else {
            XCTFail("visionOS GameScene.swift content should not be nil")
            return
        }

        // Verify GameScene.swift content
        XCTAssertTrue(gameSceneContent.contains("import Foundation"),
                      "GameScene should import Foundation")
        XCTAssertTrue(gameSceneContent.contains("import UntoldEngine"),
                      "GameScene should import UntoldEngine")
        XCTAssertTrue(gameSceneContent.contains("class GameScene"),
                      "GameScene should contain GameScene class")
        XCTAssertTrue(gameSceneContent.contains("func update(deltaTime"),
                      "GameScene should have update method")
        XCTAssertTrue(gameSceneContent.contains("func handleInput()"),
                      "GameScene should have handleInput method")
        XCTAssertFalse(gameSceneContent.contains("import SwiftUI"),
                       "GameScene should NOT import SwiftUI")
        XCTAssertFalse(gameSceneContent.contains("import UntoldEngineXR"),
                       "GameScene should NOT import UntoldEngineXR")
    }

    // MARK: - Multi-Platform Tests

    func testMultiPlatformTargetProperties() throws {
        // Given: A multi-platform build target
        let target = BuildTarget.multi(
            macOS: .v14,
            iOS: .v17,
            visionOS: .v2
        )

        // Then: Should have correct platform name
        XCTAssertEqual(target.platformName, "Multi-Platform",
                       "Multi-platform target should have 'Multi-Platform' as platformName")

        // Should contain all three platforms
        let platforms = target.platforms
        XCTAssertEqual(platforms.count, 3, "Multi-platform target should have 3 platforms")
        XCTAssertTrue(platforms.contains("macOS"), "Should include macOS")
        XCTAssertTrue(platforms.contains("iOS"), "Should include iOS")
        XCTAssertTrue(platforms.contains("visionOS"), "Should include visionOS")

        // Should return correct deployment targets for each platform
        XCTAssertEqual(target.deploymentTarget(for: "macOS"), "14.0",
                       "Should return macOS deployment target")
        XCTAssertEqual(target.deploymentTarget(for: "iOS"), "17.0",
                       "Should return iOS deployment target")
        XCTAssertEqual(target.deploymentTarget(for: "visionOS"), "2.0",
                       "Should return visionOS deployment target")
        XCTAssertNil(target.deploymentTarget(for: "tvOS"),
                     "Should return nil for unsupported platform")
    }

    func testMultiPlatformTemplateStructure() throws {
        // Given: Build settings for a multi-platform project
        let settings = BuildSettings(
            projectName: "MyMultiPlatformGame",
            bundleIdentifier: "com.test.multiplatform",
            outputPath: tempDirectory,
            target: .multi(macOS: .v14, iOS: .v17, visionOS: .v2)
        )

        // When: Getting template files
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: Should contain platform-specific folders for macOS
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} macOS/AppDelegate.swift"],
                        "Should have macOS-specific AppDelegate")
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} macOS/GameViewController.swift"],
                        "Should have macOS-specific GameViewController")
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} macOS/Base.lproj/Main.storyboard"],
                        "Should have macOS-specific storyboard")
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} macOS/Info.plist"],
                        "Should have macOS-specific Info.plist")

        // Should contain platform-specific folders for iOS
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} iOS/AppDelegate.swift"],
                        "Should have iOS-specific AppDelegate")
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} iOS/GameViewController.swift"],
                        "Should have iOS-specific GameViewController")
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} iOS/Base.lproj/Main.storyboard"],
                        "Should have iOS-specific storyboard")
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} iOS/Info.plist"],
                        "Should have iOS-specific Info.plist")

        // Should contain platform-specific folders for iOS AR
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} iOS AR/AppDelegate.swift"],
                        "Should have iOS AR-specific AppDelegate")
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} iOS AR/GameViewController.swift"],
                        "Should have iOS AR-specific GameViewController")
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} iOS AR/Info.plist"],
                        "Should have iOS AR-specific Info.plist")

        // Should contain platform-specific folders for visionOS
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} visionOS/{{PROJECT_NAME}}App.swift"],
                        "Should have visionOS-specific App file")
        XCTAssertNotNil(templateFiles["{{PROJECT_NAME}} visionOS/Info.plist"],
                        "Should have visionOS-specific Info.plist")

        // Should contain shared GameScene
        XCTAssertNotNil(templateFiles["Sources/{{PROJECT_NAME}}/GameScene.swift"],
                        "Should have shared GameScene in Sources folder")

        // Should NOT contain Package.swift (uses XcodeGen)
        XCTAssertNil(templateFiles["Package.swift"],
                     "Multi-platform template should not include Package.swift")
    }

    func testMultiPlatformXcodeGenSpec() throws {
        // Given: Build settings for a multi-platform project
        let settings = BuildSettings(
            projectName: "MyMultiPlatformGame",
            bundleIdentifier: "com.test.multiplatform",
            outputPath: tempDirectory,
            target: .multi(macOS: .v14, iOS: .v17, visionOS: .v2)
        )

        // When: Generating XcodeGen YAML spec
        let yamlContent = try XcodeGenProjectSpec.generateYAML(settings: settings)

        // Then: Should define all platform targets
        XCTAssertTrue(yamlContent.contains("MyMultiPlatformGame macOS:"),
                      "Should define macOS target")
        XCTAssertTrue(yamlContent.contains("MyMultiPlatformGame iOS:"),
                      "Should define iOS target")
        XCTAssertTrue(yamlContent.contains("MyMultiPlatformGame iOS AR:"),
                      "Should define iOS AR target")
        XCTAssertTrue(yamlContent.contains("MyMultiPlatformGame visionOS:"),
                      "Should define visionOS target")

        // Should specify correct platforms
        XCTAssertTrue(yamlContent.contains("platform: macOS"),
                      "Should specify macOS platform")
        XCTAssertTrue(yamlContent.contains("platform: iOS"),
                      "Should specify iOS platform")
        XCTAssertTrue(yamlContent.contains("platform: visionOS"),
                      "Should specify visionOS platform")

        // Should specify correct deployment targets
        XCTAssertTrue(yamlContent.contains("deploymentTarget: 14.0"),
                      "Should specify macOS deployment target")
        XCTAssertTrue(yamlContent.contains("deploymentTarget: 17.0"),
                      "Should specify iOS deployment target")
        XCTAssertTrue(yamlContent.contains("deploymentTarget: 2.0"),
                      "Should specify visionOS deployment target")

        // Should include all necessary packages
        XCTAssertTrue(yamlContent.contains("UntoldEngine:"),
                      "Should include UntoldEngine package")
        XCTAssertTrue(yamlContent.contains("UntoldEngineXR:"),
                      "Should include UntoldEngineXR package for visionOS")
        XCTAssertTrue(yamlContent.contains("UntoldEngineAR:"),
                      "Should include UntoldEngineAR package for iOS AR")

        // Should specify correct source paths for each target
        XCTAssertTrue(yamlContent.contains("path: MyMultiPlatformGame macOS"),
                      "Should include macOS source path")
        XCTAssertTrue(yamlContent.contains("path: MyMultiPlatformGame iOS"),
                      "Should include iOS source path")
        XCTAssertTrue(yamlContent.contains("path: MyMultiPlatformGame iOS AR"),
                      "Should include iOS AR source path")
        XCTAssertTrue(yamlContent.contains("path: MyMultiPlatformGame visionOS"),
                      "Should include visionOS source path")

        // All targets should share the same Sources folder
        // Each target references it twice: once for the source path and once for GameData
        let sourcesPattern = "path: Sources/MyMultiPlatformGame"
        let occurrences = yamlContent.components(separatedBy: sourcesPattern).count - 1
        XCTAssertEqual(occurrences, 8,
                       "All 4 targets should reference shared Sources folder (2 refs per target)")
    }

    func testMultiPlatformWithTeamID() throws {
        // Given: Multi-platform settings with team ID
        let settings = BuildSettings(
            projectName: "MyGame",
            bundleIdentifier: "com.test.game",
            outputPath: tempDirectory,
            target: .multi(macOS: .v14, iOS: .v17, visionOS: .v2),
            teamID: "ABC123XYZ"
        )

        // When: Generating XcodeGen YAML spec
        let yamlContent = try XcodeGenProjectSpec.generateYAML(settings: settings)

        // Then: Team ID should be present for all targets
        let teamIDPattern = "DEVELOPMENT_TEAM: ABC123XYZ"
        let occurrences = yamlContent.components(separatedBy: teamIDPattern).count - 1
        XCTAssertGreaterThanOrEqual(occurrences, 4,
                                    "Team ID should be set for all targets")
    }

    func testMultiPlatformBundleIdentifiers() throws {
        // Given: Multi-platform settings
        let bundleID = "com.company.mygame"
        let settings = BuildSettings(
            projectName: "MyGame",
            bundleIdentifier: bundleID,
            outputPath: tempDirectory,
            target: .multi(macOS: .v14, iOS: .v17, visionOS: .v2)
        )

        // When: Generating XcodeGen YAML spec
        let yamlContent = try XcodeGenProjectSpec.generateYAML(settings: settings)

        // Then: Bundle identifier should be consistent across non-AR targets
        XCTAssertTrue(yamlContent.contains("PRODUCT_BUNDLE_IDENTIFIER: \(bundleID)"),
                      "Should set bundle identifier for regular targets")

        // iOS AR should have .ar suffix
        XCTAssertTrue(yamlContent.contains("PRODUCT_BUNDLE_IDENTIFIER: \(bundleID).ar"),
                      "iOS AR target should have .ar suffix")
    }

    func testMultiPlatformDependenciesConfiguration() throws {
        // Given: Multi-platform settings
        let settings = BuildSettings(
            projectName: "MyGame",
            bundleIdentifier: "com.test.game",
            outputPath: tempDirectory,
            target: .multi(macOS: .v14, iOS: .v17, visionOS: .v2)
        )

        // When: Generating XcodeGen YAML spec
        let yamlContent = try XcodeGenProjectSpec.generateYAML(settings: settings)

        // Then: Each target should have appropriate dependencies
        // macOS and iOS (non-AR) should have UntoldEngine
        let lines = yamlContent.components(separatedBy: "\n")
        var inMacOSTarget = false
        var inIOSTarget = false
        var inIOSARTarget = false
        var inVisionOSTarget = false

        for line in lines {
            if line.contains("MyGame macOS:") {
                inMacOSTarget = true
                inIOSTarget = false
                inIOSARTarget = false
                inVisionOSTarget = false
            } else if line.contains("MyGame iOS AR:") {
                inMacOSTarget = false
                inIOSTarget = false
                inIOSARTarget = true
                inVisionOSTarget = false
            } else if line.contains("MyGame iOS:") {
                inMacOSTarget = false
                inIOSTarget = true
                inIOSARTarget = false
                inVisionOSTarget = false
            } else if line.contains("MyGame visionOS:") {
                inMacOSTarget = false
                inIOSTarget = false
                inIOSARTarget = false
                inVisionOSTarget = true
            }

            // Check that dependencies appear in the right sections
            if line.contains("- package: UntoldEngine") {
                XCTAssertTrue(inMacOSTarget || inIOSTarget || inIOSARTarget || inVisionOSTarget,
                              "UntoldEngine should be in a target section")
            }
            if line.contains("- package: UntoldEngineAR") {
                XCTAssertTrue(inIOSARTarget, "UntoldEngineAR should only be in iOS AR target")
            }
            if line.contains("- package: UntoldEngineXR") {
                XCTAssertTrue(inVisionOSTarget, "UntoldEngineXR should only be in visionOS target")
            }
        }
    }

    func testMultiPlatformOptimizationSettings() throws {
        // Given: Multi-platform settings with specific optimization level
        let settings = BuildSettings(
            projectName: "MyGame",
            bundleIdentifier: "com.test.game",
            outputPath: tempDirectory,
            target: .multi(macOS: .v14, iOS: .v17, visionOS: .v2),
            includeDebugInfo: true,
            optimizationLevel: .speed
        )

        // When: Generating XcodeGen YAML spec
        let yamlContent = try XcodeGenProjectSpec.generateYAML(settings: settings)

        // Then: All targets should have the same optimization settings
        let releaseOptPattern = "SWIFT_OPTIMIZATION_LEVEL: -O"
        let debugOptPattern = "SWIFT_OPTIMIZATION_LEVEL: -Onone"
        let debugInfoPattern = "DEBUG_INFORMATION_FORMAT: dwarf-with-dsym"

        XCTAssertTrue(yamlContent.contains(releaseOptPattern),
                      "Should contain speed optimization for release")
        XCTAssertTrue(yamlContent.contains(debugOptPattern),
                      "Should contain no optimization for debug")
        XCTAssertTrue(yamlContent.contains(debugInfoPattern),
                      "Should include debug information")
    }

    func testMultiPlatformTemplateDoesNotIncludeStandardSinglePlatformFiles() throws {
        // Given: Multi-platform build settings
        let settings = BuildSettings(
            projectName: "MyGame",
            bundleIdentifier: "com.test.game",
            outputPath: tempDirectory,
            target: .multi(macOS: .v14, iOS: .v17, visionOS: .v2)
        )

        // When: Getting template files
        let templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)

        // Then: Should NOT include single-platform file paths
        XCTAssertNil(templateFiles["Sources/{{PROJECT_NAME}}/AppDelegate.swift"],
                     "Should not have single-platform AppDelegate path")
        XCTAssertNil(templateFiles["Sources/{{PROJECT_NAME}}/GameViewController.swift"],
                     "Should not have single-platform GameViewController path")
        XCTAssertNil(templateFiles["Sources/{{PROJECT_NAME}}/Info.plist"],
                     "Should not have single-platform Info.plist path")
        XCTAssertNil(templateFiles["Sources/{{PROJECT_NAME}}/Base.lproj/Main.storyboard"],
                     "Should not have single-platform storyboard path")

        // Should have README (common to all)
        XCTAssertNotNil(templateFiles["README.md"],
                        "Should include README.md")
    }

    func testSinglePlatformTemplatesDoNotIncludeMultiPlatformStructure() throws {
        // Given: Single platform targets
        let macOSSettings = BuildSettings(
            projectName: "MacGame",
            bundleIdentifier: "com.test.mac",
            outputPath: tempDirectory,
            target: .macOS(deployment: .v14)
        )

        let iOSSettings = BuildSettings(
            projectName: "iOSGame",
            bundleIdentifier: "com.test.ios",
            outputPath: tempDirectory,
            target: .iOS(deployment: .v17)
        )

        let visionSettings = BuildSettings(
            projectName: "VisionGame",
            bundleIdentifier: "com.test.vision",
            outputPath: tempDirectory,
            target: .visionOS(deployment: .v2)
        )

        // When: Getting template files for each
        let macOSTemplates = BuildTemplates.getTemplateFiles(for: macOSSettings.target)
        let iOSTemplates = BuildTemplates.getTemplateFiles(for: iOSSettings.target)
        let visionTemplates = BuildTemplates.getTemplateFiles(for: visionSettings.target)

        // Then: None should have platform-specific folder structure
        for templates in [macOSTemplates, iOSTemplates, visionTemplates] {
            XCTAssertNil(templates["{{PROJECT_NAME}} macOS/AppDelegate.swift"],
                         "Single-platform should not have multi-platform folder structure")
            XCTAssertNil(templates["{{PROJECT_NAME}} iOS/AppDelegate.swift"],
                         "Single-platform should not have multi-platform folder structure")
            XCTAssertNil(templates["{{PROJECT_NAME}} visionOS/{{PROJECT_NAME}}App.swift"],
                         "Single-platform should not have multi-platform folder structure")
        }
    }
}
