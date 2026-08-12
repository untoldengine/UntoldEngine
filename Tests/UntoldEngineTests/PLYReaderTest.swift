//
//  PLYReaderTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Note: These unit tests were kick-started with AI and verified by a human

import CShaderTypes
import Foundation
import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class PLYReaderTest: XCTestCase {
    var tempFileURL: URL?

    override func tearDown() async throws {
        // Clean up temporary file
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Test ASCII Format

    func test_readASCIIPLY_withBasicProperties() throws {
        // Create a simple ASCII PLY file with one Gaussian splat
        let plyContent = """
        ply
        format ascii 1.0
        comment Test PLY file for Gaussian splats
        element vertex 1
        property float x
        property float y
        property float z
        property float scale_0
        property float scale_1
        property float scale_2
        property float f_dc_0
        property float f_dc_1
        property float f_dc_2
        property float opacity
        property float rot_0
        property float rot_1
        property float rot_2
        property float rot_3
        end_header
        1.0 2.0 3.0 0.0 0.0 0.0 0.5 -0.3 0.8 0.0 1.0 0.0 0.0 0.0
        """

        // Write to temporary file
        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        // Read the file
        let splats = try PLYReader.readGaussianSplats(from: tempURL)

        // Verify we got one splat
        XCTAssertEqual(splats.count, 1, "Should read exactly one Gaussian splat")

        let splat = splats[0]

        // Verify position
        XCTAssertEqual(splat.center.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(splat.center.y, 2.0, accuracy: 0.001)
        XCTAssertEqual(splat.center.z, 3.0, accuracy: 0.001)
        XCTAssertEqual(splat.center.w, 1.0, accuracy: 0.001)

        // Verify scale (should be exp(0.0) = 1.0 for all components)
        XCTAssertEqual(splat.scale.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(splat.scale.y, 1.0, accuracy: 0.001)
        XCTAssertEqual(splat.scale.z, 1.0, accuracy: 0.001)

        // Verify color (converted from spherical harmonics)
        let C0: Float = 0.28209479177387814
        let expectedR = (0.5 * C0 + 0.5)
        let expectedG = (-0.3 * C0 + 0.5)
        let expectedB = (0.8 * C0 + 0.5)
        XCTAssertEqual(splat.color.x, expectedR, accuracy: 0.001)
        XCTAssertEqual(splat.color.y, expectedG, accuracy: 0.001)
        XCTAssertEqual(splat.color.z, expectedB, accuracy: 0.001)

        // Verify opacity (sigmoid(0.0) = 0.5)
        XCTAssertEqual(splat.color.w, 0.5, accuracy: 0.001)

        // Verify quaternion is normalized
        let quatMagnitude = sqrt(splat.quat.x * splat.quat.x +
            splat.quat.y * splat.quat.y +
            splat.quat.z * splat.quat.z +
            splat.quat.w * splat.quat.w)
        XCTAssertEqual(quatMagnitude, 1.0, accuracy: 0.001, "Quaternion should be normalized")
    }

    func test_readASCIIPLY_withMultipleSplats() throws {
        // Create ASCII PLY file with multiple splats
        let plyContent = """
        ply
        format ascii 1.0
        element vertex 3
        property float x
        property float y
        property float z
        property float scale_0
        property float scale_1
        property float scale_2
        property float f_dc_0
        property float f_dc_1
        property float f_dc_2
        property float opacity
        property float rot_0
        property float rot_1
        property float rot_2
        property float rot_3
        end_header
        1.0 0.0 0.0 0.693147 0.693147 0.693147 0.0 0.0 0.0 1.0 1.0 0.0 0.0 0.0
        0.0 2.0 0.0 0.0 0.0 0.0 0.5 0.5 0.5 -1.0 0.707 0.707 0.0 0.0
        0.0 0.0 3.0 1.386294 1.386294 1.386294 1.0 1.0 1.0 0.0 0.0 0.0 1.0 0.0
        """

        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        let splats = try PLYReader.readGaussianSplats(from: tempURL)

        // Verify count
        XCTAssertEqual(splats.count, 3, "Should read three Gaussian splats")

        // Verify first splat position
        XCTAssertEqual(splats[0].center.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(splats[0].center.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(splats[0].center.z, 0.0, accuracy: 0.001)

        // Verify first splat scale (exp(ln(2)) = 2.0)
        XCTAssertEqual(splats[0].scale.x, 2.0, accuracy: 0.01)
        XCTAssertEqual(splats[0].scale.y, 2.0, accuracy: 0.01)
        XCTAssertEqual(splats[0].scale.z, 2.0, accuracy: 0.01)

        // Verify second splat position
        XCTAssertEqual(splats[1].center.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(splats[1].center.y, 2.0, accuracy: 0.001)
        XCTAssertEqual(splats[1].center.z, 0.0, accuracy: 0.001)

        // Verify third splat position
        XCTAssertEqual(splats[2].center.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(splats[2].center.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(splats[2].center.z, 3.0, accuracy: 0.001)

        // Verify third splat scale (exp(ln(4)) = 4.0)
        XCTAssertEqual(splats[2].scale.x, 4.0, accuracy: 0.01)
        XCTAssertEqual(splats[2].scale.y, 4.0, accuracy: 0.01)
        XCTAssertEqual(splats[2].scale.z, 4.0, accuracy: 0.01)
    }

    func test_readASCIIPLY_withDefaultValues() throws {
        // Create PLY file with minimal properties (testing defaults)
        let plyContent = """
        ply
        format ascii 1.0
        element vertex 1
        property float x
        property float y
        property float z
        end_header
        5.0 10.0 15.0
        """

        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        let splats = try PLYReader.readGaussianSplats(from: tempURL)

        XCTAssertEqual(splats.count, 1)

        let splat = splats[0]

        // Position should be read correctly
        XCTAssertEqual(splat.center.x, 5.0, accuracy: 0.001)
        XCTAssertEqual(splat.center.y, 10.0, accuracy: 0.001)
        XCTAssertEqual(splat.center.z, 15.0, accuracy: 0.001)

        // Scale should default to exp(0) = 1.0
        XCTAssertEqual(splat.scale.x, 1.0, accuracy: 0.001)
        XCTAssertEqual(splat.scale.y, 1.0, accuracy: 0.001)
        XCTAssertEqual(splat.scale.z, 1.0, accuracy: 0.001)

        // Opacity should default to sigmoid(0) = 0.5
        XCTAssertEqual(splat.color.w, 0.5, accuracy: 0.001)

        // Quaternion should be normalized identity-ish
        let quatMagnitude = sqrt(splat.quat.x * splat.quat.x +
            splat.quat.y * splat.quat.y +
            splat.quat.z * splat.quat.z +
            splat.quat.w * splat.quat.w)
        XCTAssertEqual(quatMagnitude, 1.0, accuracy: 0.001)
    }

    // MARK: - Spherical Harmonics

    func test_readGaussianAsset_preservesDegreeZeroThroughThreeSphericalHarmonics() throws {
        for degree in 0 ... 3 {
            let coefficientsPerChannel = (degree + 1) * (degree + 1)
            let restCount = (coefficientsPerChannel - 1) * 3
            let restValues: [Float] = (0 ..< restCount).map { Float($0) }
            let restProperties = (0 ..< restCount).map { "property float f_rest_\($0)" }

            var lines: [String] = [
                "ply",
                "format ascii 1.0",
                "element vertex 1",
                "property float x",
                "property float y",
                "property float z",
                "property float f_dc_0",
                "property float f_dc_1",
                "property float f_dc_2",
            ]
            lines.append(contentsOf: restProperties)
            lines.append("end_header")
            let valueStrings = ["1", "2", "3", "100", "200", "300"] + restValues.map { String($0) }
            lines.append(valueStrings.joined(separator: " "))
            let plyContent = lines.joined(separator: "\n")

            let tempURL = createTempFile(content: plyContent)
            tempFileURL = tempURL
            let asset = try PLYReader.readGaussianAsset(from: tempURL)
            let sh = try XCTUnwrap(asset.sphericalHarmonics)

            XCTAssertEqual(sh.degree, degree)
            XCTAssertEqual(sh.coefficientsPerChannel, coefficientsPerChannel)
            XCTAssertEqual(sh.coefficientsPerSplat, coefficientsPerChannel * 3)

            var expected: [Float] = []
            let restPerChannel = coefficientsPerChannel - 1
            for channel in 0 ..< 3 {
                expected.append(Float((channel + 1) * 100))
                let start = channel * restPerChannel
                expected.append(contentsOf: restValues[start ..< start + restPerChannel])
            }
            XCTAssertEqual(sh.coefficients, expected)
        }
    }

    // MARK: - Negligible-Opacity Culling at Load Time

    /// Regression test for 6ca071369: `filterNegligibleOpacitySplats` drops any splat whose
    /// (post-sigmoid) opacity falls below `minRetainedOpacity` (1/255) and, when spherical
    /// harmonics are present, compacts `shCoefficients` (a flat, splat-major buffer) in lock
    /// step so coefficient blocks stay aligned with their splat after removal. The first splat
    /// here has opacity logit -10 (sigmoid ≈ 4.5e-5, below threshold); the other two use
    /// distinct, easily-identifiable f_dc/f_rest values so an off-by-one in the coefficient
    /// compaction (e.g. still slicing by the pre-filter index) would surface as a mismatched
    /// or garbled block rather than just a wrong count.
    func test_readGaussianAsset_dropsNegligibleOpacitySplatsAndCompactsCoefficients() throws {
        let plyContent = """
        ply
        format ascii 1.0
        element vertex 3
        property float x
        property float y
        property float z
        property float f_dc_0
        property float f_dc_1
        property float f_dc_2
        property float opacity
        property float f_rest_0
        property float f_rest_1
        property float f_rest_2
        property float f_rest_3
        property float f_rest_4
        property float f_rest_5
        property float f_rest_6
        property float f_rest_7
        property float f_rest_8
        end_header
        0 0 0 999 999 999 -10 999 999 999 999 999 999 999 999 999
        1 0 0 100 101 102 5 110 111 112 120 121 122 130 131 132
        2 0 0 200 201 202 5 210 211 212 220 221 222 230 231 232
        """

        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        let asset = try PLYReader.readGaussianAsset(from: tempURL)

        XCTAssertEqual(asset.splats.count, 2, "The negligible-opacity splat should be dropped, leaving the other two")
        XCTAssertEqual(asset.splats[0].center.x, 1.0, accuracy: 0.001, "Surviving splats should keep their original order")
        XCTAssertEqual(asset.splats[1].center.x, 2.0, accuracy: 0.001)

        for splat in asset.splats {
            XCTAssertGreaterThan(splat.opacity, 1.0 / 255.0, "Every surviving splat should be at or above the retention threshold")
            XCTAssertEqual(splat.color.w, splat.opacity, accuracy: 0.0001, "color.w mirrors opacity")
        }

        let sh = try XCTUnwrap(asset.sphericalHarmonics)
        XCTAssertEqual(sh.degree, 1)
        XCTAssertEqual(sh.coefficientsPerSplat, 12)
        XCTAssertEqual(sh.coefficients.count, 2 * 12, "Coefficient buffer should shrink in lock step with the splat count")

        let splat1Expected: [Float] = [100, 110, 111, 112, 101, 120, 121, 122, 102, 130, 131, 132]
        let splat2Expected: [Float] = [200, 210, 211, 212, 201, 220, 221, 222, 202, 230, 231, 232]
        XCTAssertEqual(
            Array(sh.coefficients[0 ..< 12]), splat1Expected,
            "❌ First surviving splat's coefficient block should be intact and start at index 0 " +
                "(a compaction off-by-one would pull in the culled splat's 999s or shift this block)"
        )
        XCTAssertEqual(
            Array(sh.coefficients[12 ..< 24]), splat2Expected,
            "❌ Second surviving splat's coefficient block should immediately follow the first, " +
                "not leave a gap for the culled splat or bleed into the first splat's values"
        )
    }

    func test_externalGaussianDiagnosticAssetPreservesAndPacksDegreeThreeSH() throws {
        guard let path = ProcessInfo.processInfo.environment["UNTOLD_GAUSSIAN_DIAGNOSTIC_PLY"] else {
            throw XCTSkip("Set UNTOLD_GAUSSIAN_DIAGNOSTIC_PLY to audit a production Gaussian asset")
        }

        let asset = try PLYReader.readGaussianAsset(from: URL(fileURLWithPath: path))
        let sphericalHarmonics = try XCTUnwrap(asset.sphericalHarmonics)
        XCTAssertEqual(sphericalHarmonics.degree, 3)
        XCTAssertEqual(sphericalHarmonics.coefficientsPerChannel, 16)
        XCTAssertEqual(sphericalHarmonics.coefficients.count, asset.splats.count * 48)

        let packed = try packGaussianSphericalHarmonics(
            sphericalHarmonics,
            splatCount: asset.splats.count
        )
        XCTAssertEqual(packed.metadata.degree, 3)
        XCTAssertEqual(packed.metadata.coefficientsPerChannel, 16)
        XCTAssertEqual(packed.metadata.higherOrderCoefficientsPerSplat, 45)
        XCTAssertEqual(packed.coefficients.count, asset.splats.count * 45)

        let sampleIndices = [0, asset.splats.count / 2, asset.splats.count - 1]
        var observedDirectionalChange = false
        for splatIndex in sampleIndices {
            let sourceBase = splatIndex * 48
            let packedBase = splatIndex * 45
            let higherOrder = packed.coefficients[packedBase ..< packedBase + 45].map(Float.init)
            for channel in 0 ..< 3 {
                for coefficient in 0 ..< 15 {
                    XCTAssertEqual(
                        higherOrder[channel * 15 + coefficient],
                        Float(Float16(sphericalHarmonics.coefficients[sourceBase + channel * 16 + coefficient + 1]))
                    )
                }
            }

            let splat = asset.splats[splatIndex]
            let baseColor = simd_float3(splat.color.x, splat.color.y, splat.color.z)
            let evaluated = evaluateGaussianSphericalHarmonics(
                baseColor: baseColor,
                higherOrderCoefficients: higherOrder,
                degree: 3,
                direction: simd_float3(0.25, -0.5, 0.75)
            )
            observedDirectionalChange = observedDirectionalChange || simd_distance(evaluated, baseColor) > 1e-5
        }
        XCTAssertTrue(observedDirectionalChange, "Production SH data must affect evaluated color")

        print("Gaussian diagnostic: splats=\(asset.splats.count), degree=\(sphericalHarmonics.degree), "
            + "sourceCoefficients=\(sphericalHarmonics.coefficients.count), "
            + "packedCoefficients=\(packed.coefficients.count), packedBytes=\(packed.coefficients.count * MemoryLayout<Float16>.stride)")
    }

    func test_readGaussianAsset_binaryAndASCIIHaveIdenticalSphericalHarmonics() throws {
        let propertyLines = [
            "property float x", "property float y", "property float z",
            "property float f_dc_0", "property float f_dc_1", "property float f_dc_2",
        ] + (0 ..< 9).map { "property float f_rest_\($0)" }
        let values: [Float] = (1 ... 15).map { Float($0) }

        var asciiLines = ["ply", "format ascii 1.0", "element vertex 1"]
        asciiLines.append(contentsOf: propertyLines)
        asciiLines.append("end_header")
        asciiLines.append(values.map { String($0) }.joined(separator: " "))
        let ascii = asciiLines.joined(separator: "\n")
        let asciiURL = createTempFile(content: ascii)

        var binaryHeaderLines = ["ply", "format binary_little_endian 1.0", "element vertex 1"]
        binaryHeaderLines.append(contentsOf: propertyLines)
        binaryHeaderLines.append("end_header")
        let binaryHeader = binaryHeaderLines.joined(separator: "\n") + "\n"
        let binaryURL = createTempBinaryFile(header: binaryHeader, values: values)
        defer {
            try? FileManager.default.removeItem(at: asciiURL)
            try? FileManager.default.removeItem(at: binaryURL)
        }

        let asciiAsset = try PLYReader.readGaussianAsset(from: asciiURL)
        let binaryAsset = try PLYReader.readGaussianAsset(from: binaryURL)
        XCTAssertEqual(asciiAsset.sphericalHarmonics?.degree, 1)
        XCTAssertEqual(
            asciiAsset.sphericalHarmonics?.coefficients,
            binaryAsset.sphericalHarmonics?.coefficients
        )
    }

    func test_readGaussianAsset_rejectsMalformedSphericalHarmonicSchemas() {
        let malformedPropertySets = [
            ["property float f_dc_0", "property float f_dc_1"],
            ["property float f_rest_0"],
            ["property float f_dc_0", "property float f_dc_1", "property float f_dc_2", "property float f_rest_0", "property float f_rest_2"],
            ["property float f_dc_0", "property float f_dc_1", "property float f_dc_2", "property float f_rest_bad"],
        ]

        for properties in malformedPropertySets {
            let values = Array(repeating: "0", count: 3 + properties.count).joined(separator: " ")
            let plyContent = ([
                "ply", "format ascii 1.0", "element vertex 1",
                "property float x", "property float y", "property float z",
            ] + properties + ["end_header", values]).joined(separator: "\n")
            let tempURL = createTempFile(content: plyContent)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            XCTAssertThrowsError(try PLYReader.readGaussianAsset(from: tempURL)) { error in
                guard case PLYError.invalidData = error else {
                    XCTFail("Expected invalidData, got \(error)")
                    return
                }
            }
        }
    }

    func test_packGaussianSphericalHarmonics_preservesHigherOrderChannelMajorLayout() throws {
        XCTAssertEqual(MemoryLayout<Float16>.stride, 2)

        let first = (0 ..< 12).map { Float($0) }
        let second = (100 ..< 112).map { Float($0) }
        let sphericalHarmonics = GaussianSphericalHarmonics(
            degree: 1,
            coefficientsPerChannel: 4,
            coefficients: first + second
        )

        let packed = try packGaussianSphericalHarmonics(sphericalHarmonics, splatCount: 2)
        let expected = [
            1, 2, 3, 5, 6, 7, 9, 10, 11,
            101, 102, 103, 105, 106, 107, 109, 110, 111,
        ].map(Float16.init)

        XCTAssertEqual(packed.coefficients, expected)
        XCTAssertEqual(packed.metadata.degree, 1)
        XCTAssertEqual(packed.metadata.coefficientsPerChannel, 4)
        XCTAssertEqual(packed.metadata.higherOrderCoefficientsPerSplat, 9)
    }

    func test_packGaussianSphericalHarmonics_degreeZeroRequiresNoCoefficientBuffer() throws {
        let sphericalHarmonics = GaussianSphericalHarmonics(
            degree: 0,
            coefficientsPerChannel: 1,
            coefficients: [0.1, 0.2, 0.3]
        )

        let packed = try packGaussianSphericalHarmonics(sphericalHarmonics, splatCount: 1)

        XCTAssertTrue(packed.coefficients.isEmpty)
        XCTAssertEqual(packed.metadata.degree, 0)
        XCTAssertEqual(packed.metadata.coefficientsPerChannel, 1)
        XCTAssertEqual(packed.metadata.higherOrderCoefficientsPerSplat, 0)
    }

    func test_packGaussianSphericalHarmonics_rejectsInvalidCountAndFloat16Overflow() {
        let invalidCount = GaussianSphericalHarmonics(
            degree: 1,
            coefficientsPerChannel: 4,
            coefficients: [0]
        )
        XCTAssertThrowsError(try packGaussianSphericalHarmonics(invalidCount, splatCount: 1))

        var overflowCoefficients = [Float](repeating: 0, count: 12)
        overflowCoefficients[1] = Float.greatestFiniteMagnitude
        let overflow = GaussianSphericalHarmonics(
            degree: 1,
            coefficientsPerChannel: 4,
            coefficients: overflowCoefficients
        )
        XCTAssertThrowsError(try packGaussianSphericalHarmonics(overflow, splatCount: 1))
    }

    // MARK: - Test Error Handling

    func test_invalidPLY_missingMagicNumber() {
        let plyContent = """
        notply
        format ascii 1.0
        element vertex 1
        property float x
        end_header
        1.0
        """

        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        XCTAssertThrowsError(try PLYReader.readGaussianSplats(from: tempURL)) { error in
            if case let PLYError.invalidFormat(msg) = error {
                XCTAssertTrue(msg.contains("ply"), "Error should mention missing 'ply' magic number")
            } else {
                XCTFail("Expected PLYError.invalidFormat, got \(error)")
            }
        }
    }

    func test_invalidPLY_missingEndHeader() {
        let plyContent = """
        ply
        format ascii 1.0
        element vertex 1
        property float x
        """

        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        XCTAssertThrowsError(try PLYReader.readGaussianSplats(from: tempURL)) { error in
            if case let PLYError.invalidFormat(msg) = error {
                XCTAssertTrue(msg.contains("end_header"), "Error should mention missing end_header")
            } else {
                XCTFail("Expected PLYError.invalidFormat, got \(error)")
            }
        }
    }

    func test_invalidPLY_missingVertexElement() throws {
        let plyContent = """
        ply
        format ascii 1.0
        element face 1
        property int vertex_index
        end_header
        0
        """

        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        XCTAssertThrowsError(try PLYReader.readGaussianSplats(from: tempURL)) { error in
            if case let PLYError.missingElement(element) = error {
                XCTAssertEqual(element, "vertex", "Error should mention missing 'vertex' element")
            } else {
                XCTFail("Expected PLYError.missingElement, got \(error)")
            }
        }
    }

    func test_invalidPLY_missingRequiredProperty() {
        let plyContent = """
        ply
        format ascii 1.0
        element vertex 1
        property float x
        property float y
        end_header
        1.0 2.0
        """

        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        XCTAssertThrowsError(try PLYReader.readGaussianSplats(from: tempURL)) { error in
            if case let PLYError.missingProperty(property) = error {
                XCTAssertEqual(property, "z", "Error should mention missing 'z' property")
            } else {
                XCTFail("Expected PLYError.missingProperty, got \(error)")
            }
        }
    }

    // MARK: - Test Format Detection

    func test_formatDetection_ascii() throws {
        let plyContent = """
        ply
        format ascii 1.0
        element vertex 1
        property float x
        property float y
        property float z
        end_header
        1.0 2.0 3.0
        """

        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        // Should not throw and successfully parse
        XCTAssertNoThrow(try PLYReader.readGaussianSplats(from: tempURL))
    }

    func test_formatDetection_unsupportedFormat() {
        let plyContent = """
        ply
        format binary_unknown 1.0
        element vertex 1
        property float x
        end_header
        """

        let tempURL = createTempFile(content: plyContent)
        tempFileURL = tempURL

        XCTAssertThrowsError(try PLYReader.readGaussianSplats(from: tempURL)) { error in
            if case PLYError.unsupportedFormat = error {
                // Expected error
            } else {
                XCTFail("Expected PLYError.unsupportedFormat, got \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    private func createTempFile(content: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "test_\(UUID().uuidString).ply"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to create temporary file: \(error)")
        }

        return fileURL
    }

    private func createTempBinaryFile(header: String, values: [Float]) -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).ply")
        var data = Data(header.utf8)
        for value in values {
            var bits = value.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        }
        do {
            try data.write(to: fileURL)
        } catch {
            XCTFail("Failed to create binary temporary file: \(error)")
        }
        return fileURL
    }
}
