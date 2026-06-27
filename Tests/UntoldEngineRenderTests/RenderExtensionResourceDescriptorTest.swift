//
//  RenderExtensionResourceDescriptorTest.swift
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

final class RenderExtensionResourceDescriptorTest: XCTestCase {
    func testTypedResourceIDsPreserveRawValues() {
        let textureID: RenderTextureResourceID = "water.reflection"
        let bufferID: RenderBufferResourceID = "water.uniforms"

        XCTAssertEqual(textureID.rawValue, "water.reflection")
        XCTAssertEqual(bufferID.rawValue, "water.uniforms")
    }

    func testValidTextureDescriptorHasNoValidationErrors() throws {
        let descriptor = RenderExtensionTextureDescriptor(
            id: RenderTextureResourceID("water.reflection"),
            size: .viewportScale(0.5),
            pixelFormat: .rgba16Float,
            usage: [.renderTarget, .shaderRead]
        )

        XCTAssertTrue(descriptor.validationErrors().isEmpty)
        XCTAssertNoThrow(try descriptor.validate())
        XCTAssertEqual(descriptor.label, "water.reflection")
    }

    func testTextureDescriptorReportsAllIndependentValidationErrors() {
        let descriptor = RenderExtensionTextureDescriptor(
            id: " ",
            size: .viewportScale(-0.5),
            pixelFormat: .rgba16Float,
            usage: [],
            mipMapLevels: 0,
            sampleCount: 0
        )

        XCTAssertEqual(descriptor.validationErrors(), [
            .emptyID,
            .invalidViewportScale(id: " ", scale: -0.5),
            .emptyTextureUsage(id: " "),
            .invalidMipMapLevels(id: " ", count: 0),
            .invalidSampleCount(id: " ", count: 0),
        ])
    }

    func testTextureDescriptorRejectsInvalidFixedDimensions() {
        let descriptor = RenderExtensionTextureDescriptor(
            id: "water.invalid-size",
            size: .fixed(width: 0, height: -1),
            pixelFormat: .rgba16Float,
            usage: .shaderRead
        )

        XCTAssertEqual(
            descriptor.validationErrors(),
            [.invalidTextureDimensions(id: "water.invalid-size", width: 0, height: -1)]
        )
    }

    func testTextureDescriptorRejectsMipmappedMultisampling() {
        let descriptor = RenderExtensionTextureDescriptor(
            id: "water.invalid-msaa",
            size: .fixed(width: 64, height: 64),
            pixelFormat: .rgba16Float,
            usage: .renderTarget,
            mipMapLevels: 2,
            sampleCount: 4
        )

        XCTAssertEqual(
            descriptor.validationErrors(),
            [.multisampledTextureHasMipmaps(id: "water.invalid-msaa")]
        )
    }

    func testValidBufferDescriptorHasNoValidationErrors() throws {
        let descriptor = RenderExtensionBufferDescriptor(
            id: RenderBufferResourceID("water.uniforms"),
            length: 256
        )

        XCTAssertTrue(descriptor.validationErrors().isEmpty)
        XCTAssertNoThrow(try descriptor.validate())
        XCTAssertEqual(descriptor.label, "water.uniforms")
        XCTAssertEqual(descriptor.lifetime, .persistent)
    }

    func testResourceDescriptorsAcceptTransientLifetime() {
        let texture = RenderExtensionTextureDescriptor(
            id: "water.transient-texture",
            size: .fixed(width: 8, height: 8),
            pixelFormat: .rgba8Unorm,
            usage: .renderTarget,
            lifetime: .transient
        )
        let buffer = RenderExtensionBufferDescriptor(
            id: "water.transient-buffer",
            length: 64,
            lifetime: .transient
        )

        XCTAssertEqual(texture.lifetime, .transient)
        XCTAssertEqual(buffer.lifetime, .transient)
    }

    func testBufferDescriptorRejectsEmptyIDAndInvalidLength() {
        let descriptor = RenderExtensionBufferDescriptor(id: "", length: 0)

        XCTAssertEqual(descriptor.validationErrors(), [
            .emptyID,
            .invalidBufferLength(id: "", length: 0),
        ])
        XCTAssertThrowsError(try descriptor.validate()) { error in
            XCTAssertEqual(error as? RenderExtensionResourceValidationError, .emptyID)
        }
    }
}
