//
//  USDZTextureTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import MetalKit
import ModelIO
@testable import UntoldEngine
import XCTest

final class USDZTextureTest: BaseRenderSetup {
    override func initializeAssets() {}

    // MARK: - Test: Embedded Texture URL Detection

    func test_isEmbeddedUSDZTexture_detectsEmbeddedURL() {
        // Given: A pseudo-URL for embedded texture
        let embeddedURL = URL(string: "usdz-embedded://modelName/baseColor")
        let regularURL = URL(fileURLWithPath: "/path/to/texture.png")

        // When/Then: Check URL type
        XCTAssertTrue(isEmbeddedUSDZTexture(embeddedURL), "Should detect embedded USDZ URL")
        XCTAssertFalse(isEmbeddedUSDZTexture(regularURL), "Should not detect regular file URL as embedded")
        XCTAssertFalse(isEmbeddedUSDZTexture(nil), "Should return false for nil URL")
    }

    // MARK: - Test: Material Loading with USDZ

    func test_loadUSDZModel_storesMDLTextureReferences() {
        // Create an entity and load the model
        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createSphere(), assetName: "redplayer")

        // When: Get the material
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entity),
              let material = renderComponent.mesh.first?.submeshes.first?.material
        else {
            XCTFail("Material not loaded")
            return
        }

        // Then: Check if MDLTexture references are stored for textures that exist
        // We check if baseColorURL exists, and if it's embedded, the MDLTexture should be stored
        if let baseColorURL = material.baseColorURL {
            if isEmbeddedUSDZTexture(baseColorURL) {
                XCTAssertNotNil(material.baseColorMDLTexture, "Base color MDLTexture reference should be stored for embedded textures")
            }
        }
    }

    func test_loadUSDZModel_generatesEmbeddedTextureURLs() {
        // Given: A USDZ model

        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createSphere(), assetName: "redplayer")

        // When: Get material texture URL
        if let baseColorURL = getMaterialTextureURL(entityId: entity, type: .baseColor) {
            // Then: URL should be either a usdz-embedded:// pseudo-URL (bracket-path available)
            // or an mdl-obj-<ptr> object-identity URL (no bracket path — new architecture).
            let isEmbeddedScheme = baseColorURL.scheme == "usdz-embedded"
            let isObjectIdentity = baseColorURL.absoluteString.hasPrefix("mdl-obj-")
            XCTAssertTrue(
                isEmbeddedScheme || isObjectIdentity,
                "Texture URL should use usdz-embedded:// scheme or mdl-obj- object identity, got: \(baseColorURL)"
            )
            XCTAssertFalse(baseColorURL.absoluteString.contains("Mesh_SoccerPlayer1"), "Embedded URL identity should not be mesh-scoped")

            // When bracket notation is available the URL carries a package-relative
            // texture path or an embedded_ fallback token.  Object-identity URLs are
            // opaque by design and don't carry human-readable paths.
            if isEmbeddedScheme {
                XCTAssertTrue(
                    baseColorURL.absoluteString.contains("textures/") || baseColorURL.absoluteString.contains("embedded_"),
                    "Embedded URL should use package-relative texture path when available, otherwise fallback token"
                )
            }
        }
    }

    // MARK: - Test: Texture Restoration

    func test_canRestoreEmbeddedTexture_returnsTrueWhenMDLTextureExists() {
        // Given: An entity with USDZ model

        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        // When/Then: Check if we can restore textures
        // Only check for texture types that actually exist in the model
        let hasBaseColor = getMaterialTextureURL(entityId: entity, type: .baseColor) != nil

        if hasBaseColor {
            let canRestore = canRestoreEmbeddedTexture(entityId: entity, type: .baseColor)
            // If there's a texture, we should be able to restore it
            XCTAssertTrue(canRestore, "Should be able to restore base color texture if it exists")
        }
    }

    func test_removeMaterialTexture_preservesMDLTextureReference() {
        // Given: An entity with USDZ model

        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        // Store original MDLTexture reference
        let originalMDLTexture = getMaterialMDLTexture(entityId: entity, type: .baseColor)

        // When: Remove the texture
        removeMaterialTexture(entityId: entity, textureType: .baseColor)

        // Then: MDLTexture reference should still exist
        let afterRemovalMDLTexture = getMaterialMDLTexture(entityId: entity, type: .baseColor)

        if originalMDLTexture != nil {
            XCTAssertNotNil(afterRemovalMDLTexture, "MDLTexture reference should be preserved after removal")
            XCTAssertTrue(canRestoreEmbeddedTexture(entityId: entity, type: .baseColor), "Should still be able to restore after removal")
        }
    }

    func test_restoreEmbeddedTexture_restoresOriginalTexture() {
        // Given: An entity with USDZ model

        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        // Store original URL
        let originalURL = getMaterialTextureURL(entityId: entity, type: .baseColor)

        // When: Remove and then restore the texture
        removeMaterialTexture(entityId: entity, textureType: .baseColor)
        let urlAfterRemoval = getMaterialTextureURL(entityId: entity, type: .baseColor)

        restoreEmbeddedTexture(entityId: entity, textureType: .baseColor)
        let restoredURL = getMaterialTextureURL(entityId: entity, type: .baseColor)

        // Then: Texture should be restored
        if originalURL != nil {
            XCTAssertNil(urlAfterRemoval, "Texture URL should be nil after removal")
            XCTAssertNotNil(restoredURL, "Texture URL should be restored")
            XCTAssertEqual(restoredURL?.scheme, "usdz-embedded", "Restored URL should be embedded type")
        }
    }

    func test_updateMaterialTexture_preservesMDLTextureReference() {
        // Given: An entity with USDZ model and an external texture file

        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        // Store original MDLTexture reference
        let originalMDLTexture = getMaterialMDLTexture(entityId: entity, type: .baseColor)

        // Create a temporary test texture file
        let tempDir = FileManager.default.temporaryDirectory
        let testTextureURL = tempDir.appendingPathComponent("test_texture.png")

        // Create a simple 1x1 PNG (minimal valid PNG)
        let pngData = createMinimalPNGData()
        try? pngData.write(to: testTextureURL)
        defer { try? FileManager.default.removeItem(at: testTextureURL) }

        // When: Update with external texture
        updateMaterialTexture(entityId: entity, textureType: .baseColor, path: testTextureURL)

        // Then: MDLTexture reference should still exist for restoration
        let afterUpdateMDLTexture = getMaterialMDLTexture(entityId: entity, type: .baseColor)

        if originalMDLTexture != nil {
            XCTAssertNotNil(afterUpdateMDLTexture, "MDLTexture reference should be preserved after updating with external texture")
            XCTAssertTrue(canRestoreEmbeddedTexture(entityId: entity, type: .baseColor), "Should be able to restore original after replacing with external texture")
        }
    }

    // MARK: - Test: sRGB Handling

    func test_restoreEmbeddedTexture_appliesCorrectSRGBForBaseColor() {
        // Given: An entity with USDZ model

        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        // When: Restore base color texture (should use sRGB)
        removeMaterialTexture(entityId: entity, textureType: .baseColor)
        restoreEmbeddedTexture(entityId: entity, textureType: .baseColor)

        // Then: Check if texture was restored
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entity),
              let material = renderComponent.mesh.first?.submeshes.first?.material,
              let texture = material.baseColor.texture
        else {
            // It's okay if there's no base color texture in this model
            return
        }

        // Base color should be sRGB format
        let isSRGBFormat = texture.pixelFormat == MTLPixelFormat.rgba8Unorm_srgb ||
            texture.pixelFormat == MTLPixelFormat.bgra8Unorm_srgb
        XCTAssertTrue(isSRGBFormat, "Base color texture should use sRGB pixel format")
    }

    // MARK: - Helper Functions

    /// Creates minimal valid PNG data for testing (1x1 red pixel)
    private func createMinimalPNGData() -> Data {
        // PNG signature
        var data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        // IHDR chunk (1x1 image, 8-bit RGBA)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x0D]) // Length
        data.append(contentsOf: [0x49, 0x48, 0x44, 0x52]) // "IHDR"
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01]) // Width: 1
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01]) // Height: 1
        data.append(contentsOf: [0x08, 0x06, 0x00, 0x00, 0x00]) // 8-bit RGBA
        data.append(contentsOf: [0x1F, 0x15, 0xC4, 0x89]) // CRC

        // IDAT chunk (pixel data: red)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x0C]) // Length
        data.append(contentsOf: [0x49, 0x44, 0x41, 0x54]) // "IDAT"
        data.append(contentsOf: [0x08, 0x99, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x03, 0x01, 0x01, 0x00])
        data.append(contentsOf: [0x4E, 0xFD, 0xB3, 0xD4]) // CRC

        // IEND chunk
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Length
        data.append(contentsOf: [0x49, 0x45, 0x4E, 0x44]) // "IEND"
        data.append(contentsOf: [0xAE, 0x42, 0x60, 0x82]) // CRC

        return data
    }
}
