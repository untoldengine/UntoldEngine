//
//  RenderShaderLibraryPackagingTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
@testable import UntoldEngine
import XCTest

private enum TestShaderLibraryLoaderError: Error {
    case failed
}

private final class TestRenderShaderLibraryLoader: RenderShaderLibraryLoading {
    var resourceURLResult: URL?
    var library: MTLLibrary?
    var defaultLibraryShouldFail = false
    var libraryShouldFail = false
    var libraryError: any Error = TestShaderLibraryLoaderError.failed
    private(set) var requestedResource: String?
    private(set) var requestedSubdirectory: String?
    private(set) var requestedURL: URL?
    private(set) var requestedDefaultBundle: Bundle?

    func resourceURL(
        in _: Bundle,
        resource: String,
        subdirectory: String?
    ) -> URL? {
        requestedResource = resource
        requestedSubdirectory = subdirectory
        return resourceURLResult
    }

    func makeDefaultLibrary(device _: MTLDevice, bundle: Bundle) throws -> MTLLibrary {
        requestedDefaultBundle = bundle
        if defaultLibraryShouldFail { throw libraryError }
        guard let library else { throw TestShaderLibraryLoaderError.failed }
        return library
    }

    func makeLibrary(device _: MTLDevice, url: URL) throws -> MTLLibrary {
        requestedURL = url
        if libraryShouldFail { throw libraryError }
        guard let library else { throw TestShaderLibraryLoaderError.failed }
        return library
    }
}

private final class TestPackagedShaderLibraryExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let libraryID: RenderShaderLibraryID
    let source: RenderShaderLibrarySource
    let additionalLibraries: [(id: RenderShaderLibraryID, source: RenderShaderLibrarySource)]

    init(
        id: String,
        libraryID: RenderShaderLibraryID,
        source: RenderShaderLibrarySource,
        additionalLibraries: [(id: RenderShaderLibraryID, source: RenderShaderLibrarySource)] = []
    ) {
        self.id = id
        self.libraryID = libraryID
        self.source = source
        self.additionalLibraries = additionalLibraries
    }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        registry.registerLibrary(libraryID, source: source)
        for library in additionalLibraries {
            registry.registerLibrary(library.id, source: library.source)
        }
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

private final class TestURLShaderLibraryExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let libraryID: RenderShaderLibraryID
    let url: URL

    init(id: String, libraryID: RenderShaderLibraryID, url: URL) {
        self.id = id
        self.libraryID = libraryID
        self.url = url
    }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        registry.registerLibrary(libraryID, url: url)
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

private final class TestPlatformShaderLibraryExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let libraryID: RenderShaderLibraryID

    init(id: String, libraryID: RenderShaderLibraryID) {
        self.id = id
        self.libraryID = libraryID
    }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        registry.registerPlatformLibrary(
            libraryID,
            bundle: .main,
            baseResource: "PlatformShaders",
            subdirectory: "Shaders"
        )
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

final class RenderShaderLibraryPackagingTest: BaseRenderSetup {
    func testPlatformShaderResourceNameUsesCurrentSDKSuffix() {
        #if os(visionOS)
            #if targetEnvironment(simulator)
                let expected = "ProceduralShaders-xrossim"
            #else
                let expected = "ProceduralShaders-xros"
            #endif
        #elseif os(iOS)
            #if targetEnvironment(simulator)
                let expected = "ProceduralShaders-iossim"
            #else
                let expected = "ProceduralShaders-ios"
            #endif
        #elseif os(tvOS)
            #if targetEnvironment(simulator)
                let expected = "ProceduralShaders-tvossim"
            #else
                let expected = "ProceduralShaders-tvos"
            #endif
        #else
            let expected = "ProceduralShaders-macos"
        #endif

        XCTAssertEqual(
            RenderShaderLibraryPlatformResource.resourceName(baseName: "ProceduralShaders"),
            expected
        )
    }

    func testRegisterPlatformLibraryUsesResolvedResourceName() {
        let libraryID: RenderShaderLibraryID = "com.untold.platform.shaders"
        let expectedResource = RenderShaderLibraryPlatformResource.resourceName(baseName: "PlatformShaders")
        let expectedURL = URL(fileURLWithPath: "/virtual/Shaders/\(expectedResource).metallib")
        let loader = TestRenderShaderLibraryLoader()
        loader.resourceURLResult = expectedURL
        loader.library = renderInfo.library
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }

        let renderExtension = TestPlatformShaderLibraryExtension(
            id: "com.untold.platform",
            libraryID: libraryID
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        XCTAssertEqual(loader.requestedResource, expectedResource)
        XCTAssertEqual(loader.requestedSubdirectory, "Shaders")
        XCTAssertEqual(loader.requestedURL, expectedURL)
    }

    func testBundledMetallibResolvesRelativeToProvidedBundle() {
        let libraryID: RenderShaderLibraryID = "com.untold.water.shaders"
        let expectedURL = URL(fileURLWithPath: "/virtual/Shaders/Water.metallib")
        let loader = TestRenderShaderLibraryLoader()
        loader.resourceURLResult = expectedURL
        loader.library = renderInfo.library
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }
        let renderExtension = TestPackagedShaderLibraryExtension(
            id: "com.untold.water",
            libraryID: libraryID,
            source: .metallib(
                bundle: .main,
                resource: "Water",
                subdirectory: "Shaders"
            )
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)

        XCTAssertTrue(RenderShaderLibraryManager.shared.library(libraryID) === renderInfo.library)
        XCTAssertEqual(loader.requestedResource, "Water")
        XCTAssertEqual(loader.requestedSubdirectory, "Shaders")
        XCTAssertEqual(loader.requestedURL, expectedURL)
    }

    func testMissingBundledMetallibRejectsExtensionWithStructuredError() {
        let libraryID: RenderShaderLibraryID = "com.untold.missing.shaders"
        let loader = TestRenderShaderLibraryLoader()
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }
        let renderExtension = TestPackagedShaderLibraryExtension(
            id: "com.untold.missing",
            libraryID: libraryID,
            source: .metallib(bundle: .main, resource: "Missing", subdirectory: "Shaders")
        )
        let expectedError = RenderShaderLibraryLoadingError.resourceNotFound(
            libraryID: libraryID,
            resource: "Missing",
            subdirectory: "Shaders"
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension),
            .rejectedArtifacts(
                conflicts: [],
                shaderLibraryErrors: [expectedError],
                pipelineErrors: [],
                resourceValidationErrors: []
            )
        )
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        XCTAssertNil(RenderShaderLibraryManager.shared.library(libraryID))
        XCTAssertEqual(
            RenderExtensionRegistry.shared.shaderLibraryErrors(forExtensionID: renderExtension.id),
            [expectedError]
        )
    }

    func testInvalidBundledMetallibRejectsExtension() {
        let libraryID: RenderShaderLibraryID = "com.untold.invalid.shaders"
        let loader = TestRenderShaderLibraryLoader()
        loader.resourceURLResult = URL(fileURLWithPath: "/virtual/Invalid.metallib")
        loader.libraryShouldFail = true
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }
        let renderExtension = TestPackagedShaderLibraryExtension(
            id: "com.untold.invalid",
            libraryID: libraryID,
            source: .metallib(bundle: .main, resource: "Invalid")
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).shaderLibraryErrors,
            [
                .metallibCreationFailed(
                    libraryID: libraryID,
                    resource: "Invalid",
                    subdirectory: nil,
                    reason: "failed"
                ),
            ]
        )
        XCTAssertNil(RenderShaderLibraryManager.shared.library(libraryID))
    }

    func testInvalidBundledMetallibReportsMetalReason() {
        let libraryID: RenderShaderLibraryID = "com.untold.deployment.shaders"
        let metalMessage =
            "This library is using a deployment target (0x001B0000) that is not supported on this visionOS."
        let loader = TestRenderShaderLibraryLoader()
        loader.resourceURLResult = URL(fileURLWithPath: "/virtual/Shaders/Deployment.metallib")
        loader.libraryShouldFail = true
        loader.libraryError = NSError(
            domain: "MTLLibraryErrorDomain",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: metalMessage]
        )
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }
        let renderExtension = TestPackagedShaderLibraryExtension(
            id: "com.untold.deployment",
            libraryID: libraryID,
            source: .metallib(bundle: .main, resource: "Deployment", subdirectory: "Shaders")
        )
        let expectedError = RenderShaderLibraryLoadingError.metallibCreationFailed(
            libraryID: libraryID,
            resource: "Deployment",
            subdirectory: "Shaders",
            reason: metalMessage
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).shaderLibraryErrors,
            [expectedError]
        )
        XCTAssertEqual(
            RenderExtensionRegistry.shared.shaderLibraryErrors(forExtensionID: renderExtension.id),
            [expectedError]
        )
        XCTAssertTrue(
            expectedError.description.hasSuffix("'Deployment.metallib' in 'Shaders': \(metalMessage)"),
            expectedError.description
        )
        XCTAssertNil(RenderShaderLibraryManager.shared.library(libraryID))
    }

    func testInvalidDefaultLibraryReportsReason() {
        let libraryID: RenderShaderLibraryID = "com.untold.invalid-default.shaders"
        let loader = TestRenderShaderLibraryLoader()
        loader.defaultLibraryShouldFail = true
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }
        let renderExtension = TestPackagedShaderLibraryExtension(
            id: "com.untold.invalid-default",
            libraryID: libraryID,
            source: .defaultLibrary(bundle: .main)
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).shaderLibraryErrors,
            [
                .defaultLibraryCreationFailed(
                    libraryID: libraryID,
                    bundlePath: Bundle.main.bundleURL.path,
                    reason: "failed"
                ),
            ]
        )
        XCTAssertNil(RenderShaderLibraryManager.shared.library(libraryID))
    }

    func testInvalidLibraryURLReportsReason() {
        let libraryID: RenderShaderLibraryID = "com.untold.invalid-url.shaders"
        let url = URL(fileURLWithPath: "/virtual/Invalid.metallib")
        let loader = TestRenderShaderLibraryLoader()
        loader.libraryShouldFail = true
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }
        let renderExtension = TestURLShaderLibraryExtension(
            id: "com.untold.invalid-url",
            libraryID: libraryID,
            url: url
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).shaderLibraryErrors,
            [.libraryCreationFailed(libraryID: libraryID, url: url, reason: "failed")]
        )
        XCTAssertEqual(loader.requestedURL, url)
        XCTAssertNil(RenderShaderLibraryManager.shared.library(libraryID))
    }

    func testOneFailedLibraryRollsBackAllLibrariesOwnedByExtension() {
        let directLibraryID: RenderShaderLibraryID = "com.untold.partial.direct"
        let missingLibraryID: RenderShaderLibraryID = "com.untold.partial.missing"
        let loader = TestRenderShaderLibraryLoader()
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }
        let renderExtension = TestPackagedShaderLibraryExtension(
            id: "com.untold.partial",
            libraryID: directLibraryID,
            source: .library(renderInfo.library),
            additionalLibraries: [
                (
                    id: missingLibraryID,
                    source: .metallib(bundle: .main, resource: "Missing")
                ),
            ]
        )

        guard case .rejectedArtifacts = RenderExtensionRegistry.shared.register(renderExtension) else {
            XCTFail("Expected partial shader registration to be rejected")
            return
        }

        XCTAssertNil(RenderShaderLibraryManager.shared.library(directLibraryID))
        XCTAssertNil(RenderShaderLibraryManager.shared.library(missingLibraryID))
    }

    func testDefaultLibrarySourceUsesProvidedBundle() {
        let libraryID: RenderShaderLibraryID = "com.untold.default.shaders"
        let loader = TestRenderShaderLibraryLoader()
        loader.library = renderInfo.library
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }
        let renderExtension = TestPackagedShaderLibraryExtension(
            id: "com.untold.default",
            libraryID: libraryID,
            source: .defaultLibrary(bundle: .main)
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        XCTAssertTrue(loader.requestedDefaultBundle === Bundle.main)
        XCTAssertTrue(RenderShaderLibraryManager.shared.library(libraryID) === renderInfo.library)
    }

    func testFailedPackagedReplacementRestoresDirectLibraryExtension() {
        let extensionID = "com.untold.replacement"
        let originalLibraryID: RenderShaderLibraryID = "com.untold.replacement.original"
        let replacementLibraryID: RenderShaderLibraryID = "com.untold.replacement.new"
        let original = TestPackagedShaderLibraryExtension(
            id: extensionID,
            libraryID: originalLibraryID,
            source: .library(renderInfo.library)
        )
        XCTAssertEqual(RenderExtensionRegistry.shared.register(original), .registered)

        let loader = TestRenderShaderLibraryLoader()
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer { _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader) }
        let replacement = TestPackagedShaderLibraryExtension(
            id: extensionID,
            libraryID: replacementLibraryID,
            source: .metallib(bundle: .main, resource: "Missing")
        )

        guard case .rejectedArtifacts = RenderExtensionRegistry.shared.register(replacement) else {
            XCTFail("Expected packaged replacement to be rejected")
            return
        }

        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [extensionID])
        XCTAssertTrue(
            RenderShaderLibraryManager.shared.library(originalLibraryID) === renderInfo.library
        )
        XCTAssertNil(RenderShaderLibraryManager.shared.library(replacementLibraryID))
    }

    func testDeferredPackagedShaderFailureRemovesExtensionWhenMetalBecomesReady() {
        let libraryID: RenderShaderLibraryID = "com.untold.deferred.shaders"
        let renderExtension = TestPackagedShaderLibraryExtension(
            id: "com.untold.deferred",
            libraryID: libraryID,
            source: .metallib(bundle: .main, resource: "Missing")
        )
        let device = renderInfo.device
        let library = renderInfo.library
        renderInfo.device = nil
        renderInfo.library = nil
        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [renderExtension.id])

        let loader = TestRenderShaderLibraryLoader()
        let previousLoader = RenderShaderLibraryManager.shared.replaceLoaderForTesting(loader)
        defer {
            _ = RenderShaderLibraryManager.shared.replaceLoaderForTesting(previousLoader)
            renderInfo.device = device
            renderInfo.library = library
        }
        renderInfo.device = device
        renderInfo.library = library

        RenderExtensionRegistry.shared.registerPipelines()

        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        XCTAssertEqual(
            RenderExtensionRegistry.shared.shaderLibraryErrors(forExtensionID: renderExtension.id),
            [
                .resourceNotFound(
                    libraryID: libraryID,
                    resource: "Missing",
                    subdirectory: nil
                ),
            ]
        )
    }
}
