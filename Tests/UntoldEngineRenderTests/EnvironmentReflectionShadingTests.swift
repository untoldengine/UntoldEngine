//
//  EnvironmentReflectionShadingTests.swift
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

/// What a surface reflects of the environment around it, with no other light on it.
final class EnvironmentReflectionShadingTests: MaterialShadingTestCase {
    private typealias Frame = (pixels: [simd_float3], width: Int, height: Int)

    private func material(base: simd_float3 = simd_float3(1, 1, 1), metallic: Float, roughness: Float) -> RuntimeMaterialSource {
        RuntimeMaterialSource(
            baseColorFactor: simd_float4(base, 1.0),
            metallicFactor: metallic,
            roughnessFactor: roughness
        )
    }

    /// A sphere lit by the environment alone.
    private func buildEnvironmentScene() throws {
        try buildScene(.sphere, towardsLight: nil)
        applyIBL = true
        ambientIntensity = 1.0
    }

    private static func brightness(_ color: simd_float3) -> Float {
        simd_dot(color, simd_float3(0.2126, 0.7152, 0.0722))
    }

    /// How much fine detail the middle of the frame shows: the mean step in brightness
    /// from a pixel to the next, as a share of the mean brightness. A mirror image of a
    /// busy room is full of steps; a blurred one has next to none.
    private static func detail(of frame: Frame, window: Int = 160) -> Float {
        let left = frame.width / 2 - window / 2
        let top = frame.height / 2 - window / 2
        var steps: Float = 0
        var total: Float = 0
        for row in top ..< top + window {
            for column in left ..< left + window {
                let here = brightness(frame.pixels[row * frame.width + column])
                let right = brightness(frame.pixels[row * frame.width + column + 1])
                let below = brightness(frame.pixels[(row + 1) * frame.width + column])
                steps += abs(right - here) + abs(below - here)
                total += here
            }
        }
        return total > 0 ? steps / total : 0
    }

    /// The environment is filtered once per roughness when it is loaded, and the rougher
    /// levels were never read: a rough metal reflected the room as sharply as a mirror.
    func testARoughMetalBlursWhatItReflects() throws {
        try buildEnvironmentScene()
        let polished = try Self.detail(of: shadeFrame(material(metallic: 1.0, roughness: 0.05)))
        let satin = try Self.detail(of: shadeFrame(material(metallic: 1.0, roughness: 0.5)))
        let rough = try Self.detail(of: shadeFrame(material(metallic: 1.0, roughness: 0.9)))

        XCTAssertGreaterThan(polished, 0.02, "a polished metal shows the room in detail")
        XCTAssertLessThan(satin, polished * 0.6)
        XCTAssertLessThan(rough, polished * 0.25)
    }
}
