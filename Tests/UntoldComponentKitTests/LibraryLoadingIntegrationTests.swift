//
//  LibraryLoadingIntegrationTests.swift
//  UntoldComponentKitTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldComponentKit
@testable import UntoldEngine
import XCTest

/// Builds a component library the way the editor does: `xcrun swiftc` against the Swift modules
/// of the running build, with no engine linked and undefined symbols looked up at load time.
/// Then loads it into this process and checks that it shares this process's engine, and that a
/// second revision takes over the first one's values.
///
/// Skipped, never failed, when the toolchain or the build products cannot be found.
@MainActor
final class LibraryLoadingIntegrationTests: XCTestCase {
    private var workDirectory: URL!

    override func setUp() async throws {
        resetKitTestState()
        workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldComponentKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // The libraries stay mapped (Swift images cannot be unloaded); only the files go.
        try? FileManager.default.removeItem(at: workDirectory)
    }

    func testALibraryBuiltAgainstThisBuildLoadsSharesTheEngineAndReloads() throws {
        let toolchain = try Toolchain.locate()
        let products = try BuildProducts.locate(for: Self.self)
        try Self.exposeTestBundleSymbols()

        // Revision 1
        let first = try build(revision: 1, source: Self.revisionOneSource, toolchain: toolchain, products: products)
        XCTAssertNotNil(dlopen(first.path, RTLD_NOW | RTLD_LOCAL), "dlopen failed: \(Self.lastLoaderError())")

        let discovered = ComponentPluginRegistry.shared.discover(imagePath: first.path, revision: 1, policy: .replace)
        XCTAssertEqual(discovered.registered, ["LoadedSpinner"], "the loaded entity plugin is not mistaken for a component")
        XCTAssertEqual(EditorMenuPluginRegistry.shared.discover(imagePath: first.path, revision: 1, replaceExisting: true), ["LoadedExtension"])
        XCTAssertEqual(EntityPluginRegistry.shared.discover(imagePath: first.path, revision: 1, replaceExisting: true), ["LoadedMarkerEntity"])
        XCTAssertEqual(EntityPluginRegistry.shared.entries(on: .primitives).map(\.type.displayName), ["Loaded Marker"])
        let loadedEntity = try XCTUnwrap(EntityPluginRegistry.shared.instantiate("LoadedMarkerEntity"))
        let loadedPlugin = try XCTUnwrap(ScenePluginSystem.shared.entityPlugin(on: loadedEntity))
        XCTAssertTrue(NSStringFromClass(type(of: loadedPlugin)).hasPrefix("GameComponents_r1."))
        XCTAssertEqual(loadedPlugin.untoldAttributes().map(\.name), ["radius"], "the entity's own properties, read across the image boundary")
        XCTAssertEqual(
            loadedPlugin.editorRepresentation.items, [.points([SIMD3<Float>(2, 0, 0)], tint: SIMD3<Float>(1, 1, 1))],
            "and its editor representation, which follows them"
        )
        XCTAssertEqual(ScenePluginSystem.shared.slots(on: loadedEntity).map(\.typeName), ["LoadedSpinner"], "onCreate ran in the loaded library")
        destroyEntity(entityId: loadedEntity)
        finalizePendingDestroys()

        let entity = createEntity()
        let spinner = try XCTUnwrap(ScenePluginSystem.shared.add("LoadedSpinner", to: entity))
        XCTAssertTrue(NSStringFromClass(type(of: spinner)).hasPrefix("GameComponents_r1."))
        XCTAssertEqual(
            getEntityName(entityId: entity), "named-by-loaded-library",
            "the library's onAttach wrote into this process's engine, so there is one engine, not two"
        )

        let attributes = spinner.untoldAttributes()
        XCTAssertEqual(attributes.map(\.name), ["turnSpeed", "label"])
        XCTAssertEqual(attributes[0].displayLabel, "Turn Speed")
        XCTAssertEqual(attributes[0].attribute.range, 0 ... 360)
        XCTAssertTrue(ScenePluginSystem.shared.setAttribute("turnSpeed", of: "LoadedSpinner", on: entity, to: .number(45)))

        gameMode = true
        ScenePluginSystem.shared.startPlayMode()
        ScenePluginSystem.shared.update(deltaTime: 0.5, context: makeKitTestContext())
        ScenePluginSystem.shared.stopPlayMode()
        gameMode = false
        XCTAssertEqual(ScenePluginSystem.shared.slots(on: entity).first?.payload["turnSpeed"], .number(45.5))

        let extensionType = try XCTUnwrap(EditorMenuPluginRegistry.shared.type(named: "LoadedExtension"))
        let menuItems = extensionType.init().untoldMenuItems()
        XCTAssertEqual(menuItems.map(\.menu.identifier), ["debug/Loaded/Toggle"])

        // Revision 2: same type name, one property renamed away, one added.
        let second = try build(revision: 2, source: Self.revisionTwoSource, toolchain: toolchain, products: products)
        ScenePluginSystem.shared.prepareForReload()
        XCTAssertNotNil(dlopen(second.path, RTLD_NOW | RTLD_LOCAL), "dlopen failed: \(Self.lastLoaderError())")
        let rediscovered = ComponentPluginRegistry.shared.discover(imagePath: second.path, revision: 2, policy: .replace)
        XCTAssertEqual(rediscovered.replaced, ["LoadedSpinner"])
        ScenePluginSystem.shared.finishReload()

        let reloaded = try XCTUnwrap(ScenePluginSystem.shared.component(named: "LoadedSpinner", on: entity))
        XCTAssertTrue(NSStringFromClass(type(of: reloaded)).hasPrefix("GameComponents_r2."))
        XCTAssertFalse(reloaded === spinner)
        XCTAssertFalse(spinner.isAttached)
        let payload = reloaded.attributePayload()
        XCTAssertEqual(payload["turnSpeed"], .number(45.5), "kept across the reload")
        XCTAssertEqual(payload["boost"], .number(3), "new in revision 2, takes its default")
        XCTAssertNil(payload["label"], "gone in revision 2")

        print("[LibraryLoadingIntegrationTests] compile r1: \(first.seconds)s, compile r2: \(second.seconds)s")
    }

    // MARK: - Fixtures

    private static let revisionOneSource = """
    import UntoldComponentKit
    import UntoldEngine

    final class LoadedSpinner: ComponentPlugin {
        @UntoldAttribute("Turn Speed", range: 0 ... 360) var turnSpeed: Float = 90
        @UntoldAttribute var label: String = "loaded"

        override func onAttach() {
            setEntityName(entityId: entity, name: "named-by-loaded-library")
        }

        override func onUpdate(deltaTime: Float) {
            turnSpeed += deltaTime
        }
    }

    final class LoadedExtension: EditorMenuPlugin {
        @UntoldMenu(.debug, "Loaded/Toggle") var toggle = true
    }

    final class LoadedMarkerEntity: EntityPlugin {
        @UntoldAttribute var radius: Float = 2

        override class var shelf: UntoldEntityShelf { .primitives }

        override func onCreate() {
            add(LoadedSpinner.self)
        }

        override var editorRepresentation: EditorRepresentation {
            EditorRepresentation([.points([SIMD3<Float>(radius, 0, 0)], tint: SIMD3<Float>(1, 1, 1))])
        }
    }
    """

    private static let revisionTwoSource = """
    import UntoldComponentKit
    import UntoldEngine

    final class LoadedSpinner: ComponentPlugin {
        @UntoldAttribute("Turn Speed", range: 0 ... 360) var turnSpeed: Float = 90
        @UntoldAttribute var boost: Int = 3
    }
    """

    // MARK: - Building

    private struct BuiltLibrary {
        let path: String
        let seconds: Double
    }

    private func build(revision: Int, source: String, toolchain: Toolchain, products: BuildProducts) throws -> BuiltLibrary {
        let moduleName = "GameComponents_r\(revision)"
        let sourceURL = workDirectory.appendingPathComponent("\(moduleName).swift")
        let libraryURL = workDirectory.appendingPathComponent("\(moduleName).dylib")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)

        #if arch(arm64)
            let architecture = "arm64"
        #else
            let architecture = "x86_64"
        #endif

        let arguments = [
            "-emit-library", "-parse-as-library",
            "-o", libraryURL.path,
            "-module-name", moduleName,
            "-swift-version", "5", "-Onone",
            "-D", "UNTOLD_EDITOR",
            "-target", "\(architecture)-apple-macosx14.0",
            "-sdk", toolchain.sdkPath,
            "-I", products.modulesDirectory.path,
            "-Xcc", "-fmodule-map-file=\(products.cShaderTypesModuleMap.path)",
            "-Xlinker", "-undefined", "-Xlinker", "dynamic_lookup",
            sourceURL.path,
        ]

        let started = Date()
        let result = try Toolchain.run(toolchain.swiftc, arguments)
        let seconds = Date().timeIntervalSince(started)

        if result.status != 0, result.output.contains("compiled with") || result.output.contains("cannot be imported") {
            throw XCTSkip("xcrun's swiftc differs from the compiler that built these tests:\n\(result.output)")
        }
        XCTAssertEqual(result.status, 0, "swiftc failed:\n\(result.output)")
        return BuiltLibrary(path: libraryURL.path, seconds: (seconds * 100).rounded() / 100)
    }

    /// XCTest loads this bundle with local symbol scope. A library built with
    /// `-undefined dynamic_lookup` resolves through the global scope, where the editor's
    /// executable always is, so promote the bundle to match.
    private static func exposeTestBundleSymbols() throws {
        guard let binary = Bundle(for: LibraryLoadingIntegrationTests.self).executablePath else {
            throw XCTSkip("the test bundle has no executable path")
        }
        if dlopen(binary, RTLD_NOW | RTLD_NOLOAD | RTLD_GLOBAL) == nil {
            throw XCTSkip("could not promote the test bundle to global scope: \(lastLoaderError())")
        }
    }

    private static func lastLoaderError() -> String {
        dlerror().map { String(cString: $0) } ?? "no loader error"
    }
}

// MARK: - Environment

private struct Toolchain {
    let swiftc: String
    let sdkPath: String

    static func locate() throws -> Toolchain {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/xcrun") else {
            throw XCTSkip("xcrun is not available")
        }
        let compiler = try run("/usr/bin/xcrun", ["--find", "swiftc"])
        let sdk = try run("/usr/bin/xcrun", ["--sdk", "macosx", "--show-sdk-path"])
        guard compiler.status == 0, sdk.status == 0 else {
            throw XCTSkip("xcrun could not find swiftc or the macOS SDK")
        }
        return Toolchain(
            swiftc: compiler.output.trimmingCharacters(in: .whitespacesAndNewlines),
            sdkPath: sdk.output.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}

/// Where this build left the Swift modules and the generated module map of the engine's C
/// target. SwiftPM has two layouts; Xcode's matches the newer one.
private struct BuildProducts {
    let modulesDirectory: URL
    let cShaderTypesModuleMap: URL

    static func locate(for testClass: AnyClass) throws -> BuildProducts {
        let fileManager = FileManager.default
        let productsDirectory = Bundle(for: testClass).bundleURL.deletingLastPathComponent()

        let moduleCandidates = [productsDirectory, productsDirectory.appendingPathComponent("Modules")]
        let moduleMapCandidates = [
            productsDirectory.appendingPathComponent("../../Intermediates.noindex/GeneratedModuleMaps/CShaderTypes.modulemap"),
            productsDirectory.appendingPathComponent("CShaderTypes.build/module.modulemap"),
        ]

        guard let modules = moduleCandidates.first(where: {
            fileManager.fileExists(atPath: $0.appendingPathComponent("UntoldEngine.swiftmodule").path)
                && fileManager.fileExists(atPath: $0.appendingPathComponent("UntoldComponentKit.swiftmodule").path)
        }) else {
            throw XCTSkip("no UntoldEngine/UntoldComponentKit swiftmodules next to \(productsDirectory.path)")
        }
        guard let moduleMap = moduleMapCandidates.map(\.standardizedFileURL).first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            throw XCTSkip("no CShaderTypes module map for the build at \(productsDirectory.path)")
        }
        return BuildProducts(modulesDirectory: modules, cShaderTypesModuleMap: moduleMap)
    }
}
