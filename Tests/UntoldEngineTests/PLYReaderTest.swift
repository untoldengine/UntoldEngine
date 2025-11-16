//
//  PLYReaderTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

// Note: These unit tests were kick-started with AI and verified by a human

import CShaderTypes
import Foundation
import simd
@testable import UntoldEngine
import XCTest

final class PLYReaderTest: XCTestCase {
    var tempFileURL: URL?

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        // Clean up temporary file
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        super.tearDown()
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
}
