//
//  RenderExtensionDiagnosticsTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

private enum PlainTestError: Error {
    case plain
}

private struct LocalizedTestError: LocalizedError {
    var errorDescription: String? {
        "localized test failure"
    }
}

/// The text Metal reports for a metallib stamped for a newer OS than the device runs.
private let metalDeploymentTargetMessage =
    "This library is using a deployment target (0x001B0000) that is not supported on this visionOS."

private func makeMetalLibraryError() -> NSError {
    NSError(
        domain: "MTLLibraryErrorDomain",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: metalDeploymentTargetMessage]
    )
}

final class RenderExtensionDiagnosticsTests: XCTestCase {
    func testFailureReasonUsesLocalizedDescriptionOfNSError() {
        XCTAssertEqual(failureReason(for: makeMetalLibraryError()), metalDeploymentTargetMessage)
    }

    func testFailureReasonUsesErrorDescriptionOfLocalizedError() {
        XCTAssertEqual(failureReason(for: LocalizedTestError()), "localized test failure")
    }

    func testFailureReasonDescribesPlainSwiftError() {
        XCTAssertEqual(failureReason(for: PlainTestError.plain), "plain")
    }

    func testShaderLibraryCreationFailuresDescribeTheirReason() {
        let libraryID: RenderShaderLibraryID = "com.untold.test.shaders"

        XCTAssertEqual(
            RenderShaderLibraryLoadingError.metallibCreationFailed(
                libraryID: libraryID,
                resource: "Water",
                subdirectory: "Shaders",
                reason: metalDeploymentTargetMessage
            ).description,
            "Failed to create shader library 'com.untold.test.shaders' from bundled metallib 'Water.metallib' in 'Shaders': \(metalDeploymentTargetMessage)"
        )
        XCTAssertEqual(
            RenderShaderLibraryLoadingError.metallibCreationFailed(
                libraryID: libraryID,
                resource: "Water",
                subdirectory: nil,
                reason: "unreadable"
            ).description,
            "Failed to create shader library 'com.untold.test.shaders' from bundled metallib 'Water.metallib': unreadable"
        )
        XCTAssertEqual(
            RenderShaderLibraryLoadingError.defaultLibraryCreationFailed(
                libraryID: libraryID,
                bundlePath: "/virtual/Plugin.bundle",
                reason: "no default library"
            ).description,
            "Failed to create default shader library 'com.untold.test.shaders' from bundle '/virtual/Plugin.bundle': no default library"
        )
        XCTAssertEqual(
            RenderShaderLibraryLoadingError.libraryCreationFailed(
                libraryID: libraryID,
                url: URL(fileURLWithPath: "/virtual/Water.metallib"),
                reason: "unreadable"
            ).description,
            "Failed to create shader library 'com.untold.test.shaders' from '/virtual/Water.metallib': unreadable"
        )
    }

    func testPipelineCreationFailureDescribesItsReason() {
        XCTAssertEqual(
            RenderExtensionPipelineError.creationFailed(
                kind: .renderPipeline,
                pipelineID: "com.untold.test.pipeline",
                reason: "fragment output mismatch"
            ).description,
            "Failed to create extension \(RenderExtensionArtifactKind.renderPipeline.rawValue) 'com.untold.test.pipeline': fragment output mismatch"
        )
    }

    func testPipelineFailureReasonUnwrapsMetalError() {
        let creationError = PipelineCreationError.pipelineStateCreationFailed(underlying: makeMetalLibraryError())

        XCTAssertEqual(creationError.reason, metalDeploymentTargetMessage)
        XCTAssertEqual(RenderExtensionPipelineFailureReason.describe(creationError), metalDeploymentTargetMessage)
        XCTAssertEqual(RenderExtensionPipelineFailureReason.describe(PlainTestError.plain), "plain")
    }

    func testPipelineCreationErrorReasonsNameTheMissingPiece() {
        XCTAssertEqual(
            PipelineCreationError.missingFunction(name: "vertexMain").reason,
            "shader function 'vertexMain' not found"
        )
        XCTAssertEqual(
            PipelineCreationError.missingShaderLibrary(usage: "vertex shader 'vertexMain'").reason,
            "missing shader library for vertex shader 'vertexMain'"
        )
        XCTAssertEqual(PipelineCreationError.metalUnavailable.reason, "Metal device is not available")
    }
}
