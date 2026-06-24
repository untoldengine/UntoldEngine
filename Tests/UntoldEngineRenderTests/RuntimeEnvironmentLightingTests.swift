//
//  RuntimeEnvironmentLightingTests.swift
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

final class RuntimeEnvironmentLightingTests: XCTestCase {
    override func tearDown() {
        RuntimeEnvironmentLightingStore.shared.reset()
        super.tearDown()
    }

    func testDefaultModePreservesStaticIBLBehavior() {
        RuntimeEnvironmentLightingStore.shared.reset()

        let resolved = RuntimeEnvironmentLightingStore.shared.resolve(
            staticIrradianceMap: nil,
            staticSpecularMap: nil,
            staticBRDFMap: nil,
            staticIBLEnabled: true,
            ambientIntensity: 0.7
        )

        XCTAssertEqual(resolved.mode, .staticIBL)
        XCTAssertTrue(resolved.applyIBL)
        XCTAssertEqual(resolved.ambientIntensity, 0.7, accuracy: 0.0001)
        XCTAssertNil(resolved.fallbackReason)
    }

    func testAuthoredOnlyDisablesIBLWithoutChangingStaticTextureInputs() {
        RuntimeEnvironmentLightingStore.shared.mode = .authoredOnly

        let resolved = RuntimeEnvironmentLightingStore.shared.resolve(
            staticIrradianceMap: nil,
            staticSpecularMap: nil,
            staticBRDFMap: nil,
            staticIBLEnabled: true,
            ambientIntensity: 0.4
        )

        XCTAssertEqual(resolved.mode, .authoredOnly)
        XCTAssertFalse(resolved.applyIBL)
        XCTAssertEqual(resolved.ambientIntensity, 0.4, accuracy: 0.0001)
    }

    func testRealWorldEstimateFallsBackToStaticIBLWhenNoXRLightingIsAvailable() {
        RuntimeEnvironmentLightingStore.shared.mode = .realWorldEstimate

        let resolved = RuntimeEnvironmentLightingStore.shared.resolve(
            staticIrradianceMap: nil,
            staticSpecularMap: nil,
            staticBRDFMap: nil,
            staticIBLEnabled: true,
            ambientIntensity: 0.5
        )

        XCTAssertEqual(resolved.mode, .staticIBL)
        XCTAssertTrue(resolved.applyIBL)
        XCTAssertEqual(resolved.ambientIntensity, 0.5, accuracy: 0.0001)
        XCTAssertEqual(resolved.fallbackReason, "XR lighting unavailable")
    }

    func testInvalidXRLightingFallsBackToStaticIBL() {
        RuntimeEnvironmentLightingStore.shared.mode = .realWorldEstimate
        RuntimeEnvironmentLightingStore.shared.publishXRLighting(
            RuntimeEnvironmentLighting(
                irradianceMap: nil,
                specularMap: nil,
                brdfMap: nil,
                intensityScale: 2.0,
                isValid: false
            )
        )

        let resolved = RuntimeEnvironmentLightingStore.shared.resolve(
            staticIrradianceMap: nil,
            staticSpecularMap: nil,
            staticBRDFMap: nil,
            staticIBLEnabled: false,
            ambientIntensity: 0.2
        )

        XCTAssertEqual(resolved.mode, .staticIBL)
        XCTAssertFalse(resolved.applyIBL)
        XCTAssertEqual(resolved.ambientIntensity, 0.2, accuracy: 0.0001)
        XCTAssertEqual(resolved.fallbackReason, "XR lighting unavailable")
    }

    func testRenderingEnvironmentSettingUpdatesLightingMode() {
        setRendering(.environment(.lightingMode(.realWorldEstimate)))

        XCTAssertEqual(RuntimeEnvironmentLightingStore.shared.mode, .realWorldEstimate)
    }

    func testRenderingEnvironmentSettingUpdatesRealWorldLightingContribution() {
        setRendering(.environment(.realWorldLightingContribution(0.35)))

        XCTAssertEqual(RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution, 0.35, accuracy: 0.0001)
    }

    func testValidXRLightingOverridesStaticIBLAndAppliesIntensityScale() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is required for texture-backed XR lighting test")
        }

        let xrIrradiance = try makeTexture(device: device, label: "XR Irradiance")
        let xrSpecular = try makeTexture(device: device, label: "XR Specular")
        let xrBRDF = try makeTexture(device: device, label: "XR BRDF")
        let staticIrradiance = try makeTexture(device: device, label: "Static Irradiance")
        let staticSpecular = try makeTexture(device: device, label: "Static Specular")
        let staticBRDF = try makeTexture(device: device, label: "Static BRDF")

        RuntimeEnvironmentLightingStore.shared.mode = .realWorldEstimate
        RuntimeEnvironmentLightingStore.shared.publishXRLighting(
            RuntimeEnvironmentLighting(
                irradianceMap: xrIrradiance,
                specularMap: xrSpecular,
                brdfMap: xrBRDF,
                intensityScale: 1.5,
                isValid: true
            )
        )

        let resolved = RuntimeEnvironmentLightingStore.shared.resolve(
            staticIrradianceMap: staticIrradiance,
            staticSpecularMap: staticSpecular,
            staticBRDFMap: staticBRDF,
            staticIBLEnabled: false,
            ambientIntensity: 0.4
        )

        XCTAssertEqual(resolved.mode, .realWorldEstimate)
        XCTAssertTrue(resolved.applyIBL)
        XCTAssertTrue(resolved.irradianceMap === xrIrradiance)
        XCTAssertTrue(resolved.specularMap === xrSpecular)
        XCTAssertTrue(resolved.brdfMap === xrBRDF)
        XCTAssertEqual(resolved.ambientIntensity, 0.6, accuracy: 0.0001)
        XCTAssertNil(resolved.fallbackReason)
    }

    func testRealWorldLightingContributionScalesExistingXRLighting() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device is required for texture-backed XR lighting test")
        }

        RuntimeEnvironmentLightingStore.shared.mode = .realWorldEstimate
        RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution = 0.25
        try RuntimeEnvironmentLightingStore.shared.publishXRLighting(
            RuntimeEnvironmentLighting(
                irradianceMap: makeTexture(device: device, label: "XR Irradiance"),
                specularMap: makeTexture(device: device, label: "XR Specular"),
                brdfMap: makeTexture(device: device, label: "XR BRDF"),
                intensityScale: 2.0,
                isValid: true
            )
        )

        let resolved = RuntimeEnvironmentLightingStore.shared.resolve(
            staticIrradianceMap: nil,
            staticSpecularMap: nil,
            staticBRDFMap: nil,
            staticIBLEnabled: true,
            ambientIntensity: 0.8
        )

        XCTAssertEqual(resolved.ambientIntensity, 0.4, accuracy: 0.0001)
        XCTAssertNil(resolved.fallbackReason)
    }

    func testRealWorldLightingContributionClampsNegativeValues() {
        RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution = -0.5

        XCTAssertEqual(RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution, 0.0, accuracy: 0.0001)
    }

    func testIncompleteXRLightingFallsBackWithoutApplyingIntensityScale() {
        RuntimeEnvironmentLightingStore.shared.mode = .realWorldEstimate
        RuntimeEnvironmentLightingStore.shared.publishXRLighting(
            RuntimeEnvironmentLighting(
                irradianceMap: nil,
                specularMap: nil,
                brdfMap: nil,
                intensityScale: 2.5,
                isValid: true
            )
        )

        let resolved = RuntimeEnvironmentLightingStore.shared.resolve(
            staticIrradianceMap: nil,
            staticSpecularMap: nil,
            staticBRDFMap: nil,
            staticIBLEnabled: true,
            ambientIntensity: 0.4
        )

        XCTAssertEqual(resolved.mode, .staticIBL)
        XCTAssertEqual(resolved.ambientIntensity, 0.4, accuracy: 0.0001)
        XCTAssertEqual(resolved.fallbackReason, "XR lighting unavailable")
    }

    private func makeTexture(device: MTLDevice, label: String) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw XCTSkip("Unable to allocate test texture: \(label)")
        }

        texture.label = label
        return texture
    }
}
