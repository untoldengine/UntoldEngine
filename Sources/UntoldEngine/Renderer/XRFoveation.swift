//
//  XRFoveation.swift
//  UntoldEngine
//
//  Variable-rate rasterization in XR. With foveation enabled in its layer configuration, the
//  visionOS compositor hands the engine, per eye and per frame, a rasterization rate map and
//  colour and depth textures of the map's physical size — smaller than the screen the eye
//  sees. The GPU draws through the map, dense where the eyes look and coarse in the periphery,
//  and the compositor unwarps the texture on the way to the display; a layer configured this
//  way also accepts a render quality above the platform default, which a uniform layer does not.
//
//  What this asks of the renderer: every pass that rasterizes scene geometry at drawable size
//  attaches the eye's map to its descriptor and sets its viewport in the map's screen space
//  (`applyXRFoveationToSceneRenderPassDescriptors`, `applyXRFoveationViewport`). The full-screen
//  passes that follow — SSAO, post-processing, anti-aliasing, the output transform into the
//  compositor's texture — read and write the physical textures one pixel to one and never see
//  the map; it is already baked into the layout of what they copy. Two kinds of shader do have
//  to know: one that turns a texel's position back into a direction in space (SSAO rebuilds view
//  positions from depth) and the occlusion culls, which project boxes and splats to the screen
//  and sample a depth pyramid that is laid out in the map's physical space. Both decode the
//  map's parameters (`rasterization_rate_map_decoder`, bound by `bindRateMap`), and the pyramid
//  carries the map it was drawn through into the next frame's culls (`HZBPyramidFrame`).
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import simd

/// A rasterization rate map's parameter data in a buffer the shaders decode, with the two sizes
/// a decode needs. Immutable once made, so it can travel with the depth pyramid built through
/// it (`HZBPyramidFrame.rateMapData`) into the culls of the frame after.
public final class XRRasterizationRateMapData: @unchecked Sendable {
    /// The map's parameters, as `copyParameterData(buffer:offset:)` wrote them at offset 0.
    public let buffer: MTLBuffer
    /// The map's screen size in pixels: the space viewports and clip-space positions live in.
    public let screenSize: simd_float2
    /// The size in pixels of the textures drawn through the map (layer 0).
    public let physicalSize: simd_float2

    public init(buffer: MTLBuffer, screenSize: simd_float2, physicalSize: simd_float2) {
        self.buffer = buffer
        self.screenSize = screenSize
        self.physicalSize = physicalSize
    }

    /// Copies `rateMap`'s parameters into `buffer`, which must be shared and at least
    /// `rateMap.parameterDataSizeAndAlign.size` bytes long; nil when it is shorter.
    public convenience init?(rateMap: MTLRasterizationRateMap, buffer: MTLBuffer) {
        let size = rateMap.parameterDataSizeAndAlign.size
        guard size > 0, buffer.length >= size else { return nil }
        rateMap.copyParameterData(buffer: buffer, offset: 0)
        let screen = rateMap.screenSize
        let physical = rateMap.physicalSize(layer: 0)
        self.init(
            buffer: buffer,
            screenSize: simd_float2(Float(screen.width), Float(screen.height)),
            physicalSize: simd_float2(Float(physical.width), Float(physical.height))
        )
    }

    /// What the shaders bind next to the buffer: the screen size in xy, the physical size in
    /// zw. A zero x is the "no map" word (`rateMapSizes(nil)`).
    public var sizes: simd_float4 {
        simd_float4(screenSize.x, screenSize.y, physicalSize.x, physicalSize.y)
    }
}

/// The rate map of the eye being drawn, as `UntoldEngineXR` hands it to the renderer for each
/// eye of each frame (`renderInfo.xrFoveation`); nil when the frame is drawn uniformly — the
/// layer configured without foveation, the simulator, or `.foveatedRendering(.disabled)`.
public struct XRFoveationFrame {
    public let rateMap: MTLRasterizationRateMap
    /// The eye's viewport in the map's screen space (`view.textureMap.viewport`), which every
    /// encoder drawing through the map sets explicitly: the default is the physical texture's.
    public let viewport: MTLViewport
    public let rateMapData: XRRasterizationRateMapData

    public init(rateMap: MTLRasterizationRateMap, viewport: MTLViewport, rateMapData: XRRasterizationRateMapData) {
        self.rateMap = rateMap
        self.viewport = viewport
        self.rateMapData = rateMapData
    }

    public var screenSize: simd_float2 {
        rateMapData.screenSize
    }

    public var physicalSize: simd_float2 {
        rateMapData.physicalSize
    }
}

/// Attaches the current eye's rate map to the descriptors of the passes that rasterize the scene
/// at drawable size — the G-buffer + light pass, the deferred colour the transparency, wireframe
/// and debug passes draw into, the environment, sky or grid background, the splats and the
/// gizmos — or detaches it when the frame has none. The full-screen passes keep their
/// descriptors untouched: they copy physical pixels one to one. Called for every eye once its
/// graph is built, since a rebuild may have recreated the descriptors.
func applyXRFoveationToSceneRenderPassDescriptors() {
    let rateMap = renderInfo.xrFoveation?.rateMap
    renderInfo.offscreenRenderPassDescriptor?.rasterizationRateMap = rateMap
    renderInfo.deferredRenderPassDescriptor?.rasterizationRateMap = rateMap
    renderInfo.environmentRenderPassDescriptor?.rasterizationRateMap = rateMap
    renderInfo.gaussianRenderPassDescriptor?.rasterizationRateMap = rateMap
    renderInfo.gizmoRenderPassDescriptor?.rasterizationRateMap = rateMap
}

/// Sets the eye's screen-space viewport on an encoder that draws through the rate map; nothing
/// outside foveated XR, where the default viewport, the texture's own size, is the right one.
@inline(__always)
func applyXRFoveationViewport(_ encoder: MTLRenderCommandEncoder) {
    guard let foveation = renderInfo.xrFoveation else { return }
    encoder.setViewport(foveation.viewport)
}

/// The sizes word of a map, or the "no map" word the shaders test for.
@inline(__always)
func rateMapSizes(_ data: XRRasterizationRateMapData?) -> simd_float4 {
    data?.sizes ?? .zero
}

/// The rate map the current depth pyramid was drawn through, for the culls that sample it.
@inline(__always)
func hzbPyramidRateMapData() -> XRRasterizationRateMapData? {
    renderInfo.hzbFrame?.rateMapData
}

/// Binds a map's parameters and sizes to a kernel, or a placeholder and the "no map" word when
/// there is none: Metal wants every declared buffer bound, and the kernels read the parameters
/// only when `sizes.x > 0`.
func bindRateMap(_ data: XRRasterizationRateMapData?, to encoder: MTLComputeCommandEncoder, dataIndex: Int, sizesIndex: Int) {
    var sizes = rateMapSizes(data)
    encoder.setBuffer(data?.buffer ?? rateMapPlaceholderBuffer(), offset: 0, index: dataIndex)
    encoder.setBytes(&sizes, length: MemoryLayout<simd_float4>.stride, index: sizesIndex)
}

/// The fragment-stage form of `bindRateMap(_:to:dataIndex:sizesIndex:)`.
func bindRateMap(_ data: XRRasterizationRateMapData?, toFragmentsOf encoder: MTLRenderCommandEncoder, dataIndex: Int, sizesIndex: Int) {
    var sizes = rateMapSizes(data)
    encoder.setFragmentBuffer(data?.buffer ?? rateMapPlaceholderBuffer(), offset: 0, index: dataIndex)
    encoder.setFragmentBytes(&sizes, length: MemoryLayout<simd_float4>.stride, index: sizesIndex)
}

/// A small shared buffer bound wherever a shader declares a rate map it will not read.
private func rateMapPlaceholderBuffer() -> MTLBuffer? {
    if let buffer = bufferResources.rateMapPlaceholder {
        return buffer
    }
    guard let device = renderInfo.device else { return nil }
    let buffer = device.makeBuffer(length: 256, options: .storageModeShared)
    buffer?.label = "Rate Map Placeholder"
    bufferResources.rateMapPlaceholder = buffer
    return buffer
}
