//
//  BuildSystemCodeComponentsTests.swift
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

#if os(macOS)

    @MainActor
    final class BuildSystemCodeComponentsTests: XCTestCase {
        private var tempDirectory: URL!

        override func setUp() async throws {
            tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("BuildSystemCodeComponentsTests_\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        }

        override func tearDown() async throws {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        private func settings(
            _ target: BuildTarget = .macOS(deployment: .v15),
            enginePackage: EnginePackageReference? = nil,
            codeComponents: Bool = false
        ) -> BuildSettings {
            BuildSettings(
                projectName: "MyGame",
                bundleIdentifier: "com.test.mygame",
                outputPath: tempDirectory,
                target: target,
                enginePackage: enginePackage,
                includesCodeComponents: codeComponents
            )
        }

        private let multi = BuildTarget.multi(macOS: .v15, iOS: .v17, visionOS: .v26)

        private func occurrences(of needle: String, in text: String) -> Int {
            text.components(separatedBy: needle).count - 1
        }

        // MARK: - Spec generation

        func testDefaultSettingsGenerateTheSpecProjectsHaveAlwaysHad() throws {
            for target in [BuildTarget.macOS(deployment: .v15), .iOS(deployment: .v17), .visionOS(deployment: .v26), multi] {
                let yaml = try XcodeGenProjectSpec.generateYAML(settings: settings(target))
                XCTAssertTrue(yaml.contains("url: https://github.com/untoldengine/UntoldEngine.git"))
                XCTAssertTrue(yaml.contains("branch: develop"))
                XCTAssertFalse(yaml.contains("UntoldComponentKit"), "the kit is opt-in")
                XCTAssertFalse(yaml.contains("MyGameComponents"))
            }
        }

        func testEnginePackageReferenceIsWrittenIntoTheSpec() throws {
            let fork = "https://github.com/miolabs/UntoldEngine.git"
            let pinned = try XcodeGenProjectSpec.generateYAML(settings: settings(enginePackage: .init(url: fork, requirement: .revision("abc123"))))
            XCTAssertTrue(pinned.contains("url: \(fork)"))
            XCTAssertTrue(pinned.contains("revision: abc123"))
            XCTAssertFalse(pinned.contains("branch:"))

            let released = try XcodeGenProjectSpec.generateYAML(settings: settings(multi, enginePackage: .init(url: fork, requirement: .exactVersion("0.20.0"))))
            XCTAssertTrue(released.contains("exactVersion: 0.20.0"))
            XCTAssertFalse(released.contains("untoldengine/UntoldEngine"), "the multi-platform document honours it too")
        }

        func testSinglePlatformSpecLinksTheKitAndNeedsNoSourceEntry() throws {
            let yaml = try XcodeGenProjectSpec.generateYAML(settings: settings(codeComponents: true))

            XCTAssertEqual(occurrences(of: "product: UntoldComponentKit", in: yaml), 1)
            XCTAssertTrue(yaml.contains("- path: Sources\n"), "everything under Sources is compiled, the components folder included")
            XCTAssertFalse(yaml.contains("MyGameComponents"))
            XCTAssertTrue(yaml.contains("""
                  - package: UntoldEngine
                    product: UntoldEngineShaderSupport
                  - package: UntoldEngine
                    product: UntoldComponentKit
                settings:
            """), "the kit is one more entry of the target's dependencies")
        }

        func testMultiPlatformSpecLinksTheKitAndListsTheFolderOnEveryTarget() throws {
            let yaml = try XcodeGenProjectSpec.generateYAML(settings: settings(multi, codeComponents: true))

            XCTAssertEqual(occurrences(of: "product: UntoldComponentKit", in: yaml), 4)
            XCTAssertEqual(occurrences(of: "- path: Sources/MyGameComponents\n", in: yaml), 4)
            XCTAssertEqual(occurrences(of: "optional: true", in: yaml), 4, "generation must not fail before the folder exists")
        }

        // MARK: - Patching an existing spec

        func testPatchingAnExistingSpecGivesWhatAFreshProjectWouldHave() throws {
            for target in [BuildTarget.macOS(deployment: .v15), .visionOS(deployment: .v26), multi] {
                let before = try XcodeGenProjectSpec.generateYAML(settings: settings(target))
                let fresh = try XcodeGenProjectSpec.generateYAML(settings: settings(target, codeComponents: true))

                let patched = XcodeGenProjectSpec.addingCodeComponents(toYAML: before, projectName: "MyGame")

                XCTAssertEqual(patched, fresh, "\(target.platformName)")
                XCTAssertEqual(XcodeGenProjectSpec.addingCodeComponents(toYAML: patched, projectName: "MyGame"), patched, "idempotent")
            }
        }

        func testPatchingLeavesOtherTargetsAndTheEngineReferenceAlone() {
            let yaml = """
            name: BedroomTwin

            packages:
              UntoldEngine:
                url: https://github.com/untoldengine/UntoldEngine.git
                branch: develop
              Other:
                url: https://example.com/Other.git
                branch: main

            targets:
              BedroomTwin:
                type: application
                sources:
                  - path: Sources
                dependencies:
                  - package: UntoldEngine
                    product: UntoldEngineXR
                  - package: UntoldEngine
                    product: UntoldEngineAR
                settings:
                  base:
                    SWIFT_VERSION: 5.0
              Helper:
                type: framework
                dependencies:
                  - package: Other
                    product: Other
            """

            let patched = XcodeGenProjectSpec.addingCodeComponents(toYAML: yaml, projectName: "BedroomTwin")

            XCTAssertEqual(occurrences(of: "product: UntoldComponentKit", in: patched), 1)
            XCTAssertTrue(patched.contains("""
                    product: UntoldEngineAR
                  - package: UntoldEngine
                    product: UntoldComponentKit
                settings:
            """))
            XCTAssertTrue(patched.contains("branch: develop"), "which engine a project pins is its owner's call")
            XCTAssertTrue(patched.hasSuffix("""
                  - package: Other
                    product: Other
            """), "a target that does not use the engine is untouched")
        }

        // MARK: - Templates

        func testGameSceneRegistersCodeComponentsOnlyWhenAsked() throws {
            for target in [BuildTarget.macOS(deployment: .v15), .iOS(deployment: .v17), .visionOS(deployment: .v26)] {
                let template = try XCTUnwrap(BuildTemplates.getTemplateFiles(for: target)["Sources/{{PROJECT_NAME}}/GameScene.swift"])

                let with = BuildTemplates.expandingCodeComponentPlaceholders(in: template, settings: settings(target, codeComponents: true))
                XCTAssertTrue(with.contains("import UntoldEngine\nimport UntoldComponentKit\n"))
                XCTAssertTrue(with.contains("""
                        gameMode = true
                        // Code components: register the types linked into this app, then start them.
                        // Scenes loaded afterwards bind their saved components to these types.
                        CodeComponentRegistry.shared.discoverInMainExecutable()
                        CodeComponentSystem.install()
                        CodeComponentSystem.shared.startPlayMode()
                """), "indented like the line it replaces")

                let without = BuildTemplates.expandingCodeComponentPlaceholders(in: template, settings: settings(target))
                XCTAssertFalse(without.contains("UntoldComponentKit"))
                XCTAssertFalse(without.contains("CodeComponent"))
                XCTAssertTrue(without.contains("        gameMode = true\n        AnimationSystem.shared.isEnabled = true"), "the placeholder line is gone, not left blank")

                XCTAssertFalse(with.contains("{{CODE_COMPONENTS_"))
                XCTAssertFalse(without.contains("{{CODE_COMPONENTS_"))
            }

            let arTemplate = try XCTUnwrap(BuildTemplates.getTemplateFilesForIOSAR()["Sources/{{PROJECT_NAME}}/GameScene.swift"])
            let ar = BuildTemplates.expandingCodeComponentPlaceholders(in: arTemplate, settings: settings(.iOS(deployment: .v17), codeComponents: true))
            XCTAssertTrue(ar.contains("CodeComponentSystem.install()"))
        }

        func testPackageSwiftFollowsTheEngineReferenceAndGainsAComponentsTarget() throws {
            let template = try XCTUnwrap(BuildTemplates.getTemplateFiles(for: .macOS(deployment: .v15))["Package.swift"])

            let plain = BuildTemplates.expandingCodeComponentPlaceholders(in: template, settings: settings())
            XCTAssertTrue(plain.contains(".package(url: \"https://github.com/untoldengine/UntoldEngine.git\", branch: \"develop\")"))
            XCTAssertFalse(plain.contains("Components"))
            XCTAssertFalse(plain.contains("{{ENGINE_") || plain.contains("{{CODE_COMPONENTS_"), "only {{PROJECT_NAME}}-style variables remain for the generic pass")

            let fork = EnginePackageReference(url: "https://github.com/miolabs/UntoldEngine.git", requirement: .revision("abc123"))
            let full = BuildTemplates.expandingCodeComponentPlaceholders(in: template, settings: settings(enginePackage: fork, codeComponents: true))
            XCTAssertTrue(full.contains(".package(url: \"https://github.com/miolabs/UntoldEngine.git\", revision: \"abc123\")"))
            XCTAssertTrue(full.contains(".product(name: \"UntoldComponentKit\", package: \"UntoldEngine\"),"))
            XCTAssertTrue(full.contains("name: \"{{PROJECT_NAME}}Components\","), "the generic pass fills the project name in afterwards")
        }

        func testStarterComponentIsPartOfAProjectThatAsksForCodeComponents() {
            XCTAssertEqual(BuildTemplates.starterComponentPath, "Sources/{{PROJECT_NAME}}Components/Spinner.swift")
            XCTAssertTrue(BuildTemplates.starterComponentSwift.contains("final class Spinner: CodeComponent"))
            XCTAssertTrue(BuildTemplates.starterComponentSwift.contains("@UntoldAttribute"))
            XCTAssertEqual(BuildSystem.starterCodeComponentSource, BuildTemplates.starterComponentSwift)
        }

        // MARK: - Adding to an existing project

        func testAddCodeComponentsCreatesTheFolderPatchesTheSpecAndIsSafeToRepeat() throws {
            let root = tempDirectory.appendingPathComponent("BedroomTwin")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let spec = try XcodeGenProjectSpec.generateYAML(settings: BuildSettings(
                projectName: "BedroomTwin", bundleIdentifier: "com.test.bedroom", outputPath: tempDirectory, target: .visionOS(deployment: .v26)
            ))
            try spec.write(to: root.appendingPathComponent("project.yml"), atomically: true, encoding: .utf8)

            let first = try BuildSystem.shared.addCodeComponents(toProjectAt: root, projectName: "BedroomTwin", regenerateXcodeProject: false)

            XCTAssertTrue(first.createdStarterComponent)
            XCTAssertTrue(first.updatedProjectSpec)
            XCTAssertFalse(first.regeneratedXcodeProject)
            XCTAssertEqual(first.componentsDirectory.lastPathComponent, "BedroomTwinComponents")
            XCTAssertTrue(FileManager.default.fileExists(atPath: first.componentsDirectory.appendingPathComponent("Spinner.swift").path))
            let patched = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
            XCTAssertTrue(patched.contains("product: UntoldComponentKit"))
            XCTAssertTrue(first.notes.contains { $0.contains("discoverInMainExecutable") }, "the game still has to register components")
            XCTAssertTrue(first.notes.contains { $0.contains("pins the upstream engine") })

            let second = try BuildSystem.shared.addCodeComponents(toProjectAt: root, projectName: "BedroomTwin", regenerateXcodeProject: false)
            XCTAssertFalse(second.createdStarterComponent, "an existing component is never overwritten")
            XCTAssertFalse(second.updatedProjectSpec)
        }

        func testAddCodeComponentsWithoutASpecStillCreatesTheFolderAndSaysWhatIsLeft() throws {
            let root = tempDirectory.appendingPathComponent("Plain")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

            let result = try BuildSystem.shared.addCodeComponents(toProjectAt: root, projectName: "Plain")

            XCTAssertTrue(result.createdStarterComponent)
            XCTAssertFalse(result.updatedProjectSpec)
            XCTAssertTrue(result.notes.contains { $0.contains("No project.yml") })
        }
    }

#endif
