//
//  NormalMapShadingTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

/// How a tangent-space normal map changes the shading of a lit surface: a gray, rough
/// cube face that looks at the camera, lit by one light that comes from the right at 45
/// degrees and by nothing else, so the face is as bright as it is turned to the light.
final class NormalMapShadingTests: MaterialShadingTestCase {
    /// The face leaning 45 degrees towards the light, and 45 degrees away from it.
    private static let towardsTheLight: (red: UInt8, green: UInt8, blue: UInt8) = (218, 128, 218)
    private static let awayFromTheLight: (red: UInt8, green: UInt8, blue: UInt8) = (37, 128, 218)

    private func buildLitFace() throws {
        try buildScene(.cube, towardsLight: simd_float3(1, 0, 1))
        ambientIntensity = 0.0
    }

    private func litColor(normalMap: URL?, normalScale: Float = 1.0) throws -> simd_float3 {
        try shade(RuntimeMaterialSource(
            baseColorFactor: simd_float4(0.8, 0.8, 0.8, 1),
            normalScale: normalScale,
            metallicFactor: 0.0,
            roughnessFactor: 1.0,
            normalTexture: normalMap.map { RuntimeTextureReference(name: $0.lastPathComponent, sourceURL: $0) }
        ))
    }

    private func normalMap(_ color: (red: UInt8, green: UInt8, blue: UInt8)) throws -> URL {
        try writeTexture(red: color.red, green: color.green, blue: color.blue)
    }

    /// A flat normal map says "the surface as it is": (128, 128, 255) decodes to (0, 0, 1).
    /// It used to come out about 22 degrees off, because the stored color was normalized
    /// before the remap to [-1, 1].
    func testANeutralNormalMapShadesLikeNoNormalMap() throws {
        try buildLitFace()
        let plain = try litColor(normalMap: nil)
        let neutral = try litColor(normalMap: writeTexture(red: 128, green: 128, blue: 255))
        XCTAssertGreaterThan(plain.x, 0.01, "the face is lit")
        for channel in 0 ..< 3 {
            XCTAssertEqual(neutral[channel], plain[channel], accuracy: plain[channel] * 0.03)
        }
    }

    /// A map that leans the normal 45 degrees along the tangent turns the face to look
    /// straight at the light, or edge on to it.
    func testALeaningNormalTurnsTheFaceToTheLightOrAwayFromIt() throws {
        try buildLitFace()
        let plain = try litColor(normalMap: nil).x
        let towards = try litColor(normalMap: normalMap(Self.towardsTheLight)).x
        let away = try litColor(normalMap: normalMap(Self.awayFromTheLight)).x

        // From 45 degrees off the light to facing it: 1 / cos 45.
        XCTAssertEqual(towards, plain * Float(2.0).squareRoot(), accuracy: plain * 0.05)
        XCTAssertLessThan(away, plain * 0.05)
    }

    /// The material's normal strength: none of the map at 0, all of it at 1, part of it
    /// in between.
    func testTheNormalStrengthScalesTheMap() throws {
        try buildLitFace()
        let plain = try litColor(normalMap: nil).x
        let map = try normalMap(Self.awayFromTheLight)
        let full = try litColor(normalMap: map, normalScale: 1.0).x
        let half = try litColor(normalMap: map, normalScale: 0.5).x
        let none = try litColor(normalMap: map, normalScale: 0.0).x

        XCTAssertEqual(none, plain, accuracy: plain * 0.03)
        XCTAssertLessThan(full, plain * 0.05, "the whole map turns the face edge on to the light")
        // Half the strength leans the normal 22.5 degrees: cos 67.5 / cos 45 of the light.
        XCTAssertEqual(half, plain * 0.541, accuracy: plain * 0.04)
    }
}
