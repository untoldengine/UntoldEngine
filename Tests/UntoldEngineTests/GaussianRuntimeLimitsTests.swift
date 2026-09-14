//
//  GaussianRuntimeLimitsTests.swift
//  UntoldEngine
//
//  The per-pixel blend cap of the splat fragment shader: the platform figure, the override
//  and its clamp, and the per-draw constants that carry it to the GPU.
//

@testable import UntoldEngine
import XCTest

final class GaussianRuntimeLimitsTests: XCTestCase {
    private var savedOverride: Int?
    private var savedDisableBlendCap = false

    override func setUp() {
        super.setUp()
        savedOverride = GaussianRuntimeLimits.maxBlendedSplatsPerPixelOverride
        savedDisableBlendCap = GaussianDebugOptions.shared.disableBlendCap
        GaussianRuntimeLimits.maxBlendedSplatsPerPixelOverride = nil
        GaussianDebugOptions.shared.disableBlendCap = false
    }

    override func tearDown() {
        GaussianRuntimeLimits.maxBlendedSplatsPerPixelOverride = savedOverride
        GaussianDebugOptions.shared.disableBlendCap = savedDisableBlendCap
        super.tearDown()
    }

    func test_blendCapIsThePlatformFigureUntilOverridden() {
        #if os(macOS)
            XCTAssertEqual(GaussianRuntimeLimits.maxBlendedSplatsPerPixel, GaussianRuntimeLimits.maxBlendedSplatsPerPixelMac)
            XCTAssertEqual(GaussianRuntimeLimits.maxBlendedSplatsPerPixelMac, 128)
        #else
            XCTAssertEqual(GaussianRuntimeLimits.maxBlendedSplatsPerPixel, GaussianRuntimeLimits.maxBlendedSplatsPerPixelMobile)
        #endif
        XCTAssertEqual(GaussianRuntimeLimits.maxBlendedSplatsPerPixelMobile, 64)
        XCTAssertLessThanOrEqual(GaussianRuntimeLimits.maxBlendedSplatsPerPixelMac, 255, "the shader counts in a byte")

        GaussianRuntimeLimits.maxBlendedSplatsPerPixelOverride = 96
        XCTAssertEqual(GaussianRuntimeLimits.maxBlendedSplatsPerPixel, 96)
        GaussianRuntimeLimits.maxBlendedSplatsPerPixelOverride = 1000
        XCTAssertEqual(GaussianRuntimeLimits.maxBlendedSplatsPerPixel, 255, "clamped to the counter's range")
        GaussianRuntimeLimits.maxBlendedSplatsPerPixelOverride = 0
        XCTAssertEqual(GaussianRuntimeLimits.maxBlendedSplatsPerPixel, 1, "never zero: a zero cap would draw nothing")
        GaussianRuntimeLimits.maxBlendedSplatsPerPixelOverride = nil
        #if os(macOS)
            XCTAssertEqual(GaussianRuntimeLimits.maxBlendedSplatsPerPixel, 128)
        #endif
    }

    func test_drawConstantsCarryTheCapAndTheDebugLift() {
        let options = GaussianDebugOptions.shared
        XCTAssertEqual(Int(options.drawConstants.maxBlendedSplatsPerPixel), GaussianRuntimeLimits.maxBlendedSplatsPerPixel)
        GaussianRuntimeLimits.maxBlendedSplatsPerPixelOverride = 72
        XCTAssertEqual(options.drawConstants.maxBlendedSplatsPerPixel, 72)
        options.disableBlendCap = true
        XCTAssertEqual(options.drawConstants.maxBlendedSplatsPerPixel, 255, "the debug switch lifts the cap whatever the limit")
        options.disableBlendCap = false
        XCTAssertEqual(options.drawConstants.maxBlendedSplatsPerPixel, 72)
    }
}
