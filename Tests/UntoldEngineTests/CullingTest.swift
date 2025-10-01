//
//  CullingTest.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import CShaderTypes
import simd
@testable import UntoldEngine
import XCTest

final class CullingTest: XCTestCase {
    var camera: EntityID!
    var renderer: UntoldRenderer!
    var window: NSWindow!

    override func setUp() {
        super.setUp()
        let windowWidth = 1280
        let windowHeight = 720
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)

        window.title = "Test Window"

        // Initialize the renderer
        guard let renderer = UntoldRenderer.create() else {
            XCTFail("Failed to initialize the renderer.")
            return
        }

        window.contentView = renderer.metalView

        self.renderer = renderer

        // Initialize resources
        self.renderer.initResources()

        // Initialize projection
        let aspect = Float(windowWidth) / Float(windowHeight)
        let projectionMatrix = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov),
            aspectRatio: aspect,
            nearZ: near,
            farZ: far
        )

        renderInfo.perspectiveSpace = projectionMatrix

        camera = createEntity()
        createGameCamera(entityId: camera)
    }

    override func tearDown() {
        super.tearDown()
        destroyEntity(entityId: camera)
    }

    // CPU reference test (same math as your GPU code)
    @inline(__always)
    func cpuInFrustum(center c: simd_float3, extent e: simd_float3, planes: [simd_float4]) -> Bool {
        var epsilon: Float = 0.0001
        for p in planes {
            let n = simd_float3(p.x, p.y, p.z)
            let r = abs(n.x) * e.x + abs(n.y) * e.y + abs(n.z) * e.z
            let s = simd_dot(n, c) + p.w
            if s < -r - epsilon { return false }
        }
        return true
    }

    @discardableResult
    func dispatchFrustumCull(
        _ commandBuffer: MTLCommandBuffer,
        pipeline: MTLComputePipelineState,
        frustumPlanes: [simd_float4], // 6 planes as (nx, ny, nz, d)
        aabbs: MTLBuffer, // pointer to contiguous EntityAABB
        aabbCount: Int,
        visibleCountBuffer: MTLBuffer,
        visibilityBuffer: MTLBuffer,
        planesBuffer: MTLBuffer // temp upload buffer for planes
    ) -> Bool {
        guard aabbCount > 0 else { return true }

        // Upload planes
        precondition(frustumPlanes.count == 6)
        memcpy(planesBuffer.contents(), frustumPlanes, MemoryLayout<simd_float4>.stride * 6)

        let enc = commandBuffer.makeComputeCommandEncoder()!
        enc.label = "Frustum Culling (unit-testable)"
        enc.setComputePipelineState(pipeline)
        enc.setBuffer(planesBuffer, offset: 0, index: Int(frustumCullingPassPlanesIndex.rawValue))
        enc.setBuffer(aabbs, offset: 0, index: Int(frustumCullingPassObjectIndex.rawValue)) // set by caller
        var n32 = UInt32(aabbCount)
        enc.setBytes(&n32, length: MemoryLayout<UInt32>.stride, index: Int(frustumCullingPassObjectCountIndex.rawValue))
        enc.setBuffer(visibleCountBuffer, offset: 0, index: Int(frustumCullingPassVisibleCountIndex.rawValue))
        enc.setBuffer(visibilityBuffer, offset: 0, index: Int(frustumCullingPassVisibilityIndex.rawValue))

        // Threads config (same logic you use)
        let tew = pipeline.threadExecutionWidth
        let maxT = pipeline.maxTotalThreadsPerThreadgroup
        let target = 256
        var block = min(target, maxT)
        block = (block / tew) * tew
        block = max(block, tew)

        enc.dispatchThreads(MTLSize(width: aabbCount, height: 1, depth: 1),
                            threadsPerThreadgroup: MTLSize(width: block, height: 1, depth: 1))
        enc.endEncoding()
        return true
    }

    private func unprojectCorners(viewProj: simd_float4x4,
                                  ndcNear: Float = 0, ndcFar: Float = 1) -> [SIMD3<Float>]
    {
        let inv = simd_inverse(viewProj)
        func up(_ ndc: SIMD3<Float>) -> SIMD3<Float> {
            let p = inv * SIMD4(ndc, 1)
            return SIMD3(p.x, p.y, p.z) / p.w
        }
        return [
            up([-1, +1, ndcNear]), up([+1, +1, ndcNear]),
            up([-1, -1, ndcNear]), up([+1, -1, ndcNear]),
            up([-1, +1, ndcFar]), up([+1, +1, ndcFar]),
            up([-1, -1, ndcFar]), up([+1, -1, ndcFar]),
        ]
    }

    private func pointPlaneDistance(_ p: Plane, _ x: SIMD3<Float>) -> Float {
        simd_dot(p.n, x) + p.d
    }

    func testBuildFrustum() {
        let windowWidth = 1280
        let windowHeight = 720

        // Initialize projection
        let aspect = Float(windowWidth) / Float(windowHeight)
        let projectionMatrix = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov),
            aspectRatio: aspect,
            nearZ: near,
            farZ: far
        )

        renderInfo.perspectiveSpace = projectionMatrix

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findGameCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        let viewProjection: simd_float4x4 = simd_mul(renderInfo.perspectiveSpace, cameraComponent.viewSpace)

        let F = buildFrustum(from: viewProjection, ndcNear: 0, ndcFar: 1)

        // Frustum center should evaluate >= 0 for all planes
        let corners = unprojectCorners(viewProj: viewProjection)
        let center = corners.reduce(SIMD3<Float>(repeating: 0), +) / 8
        for p in F.planes {
            XCTAssertGreaterThanOrEqual(pointPlaneDistance(p, center), -1e-5, "Frustum center should be inside (plane inward)")
        }

        // Each "face" corners should lie on its plane (≈ 0)
        // Index map: [ntl, ntr, nbl, nbr, ftl, ftr, fbl, fbr]
        let ntl = corners[0], ntr = corners[1], nbl = corners[2], nbr = corners[3]
        let ftl = corners[4], ftr = corners[5], fbl = corners[6], fbr = corners[7]

        let eps: Float = 5e-3
        // L, R, B, T, N, F
        XCTAssertEqual(pointPlaneDistance(F.planes[0], ntl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[0], nbl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[0], ftl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[0], fbl), 0, accuracy: eps)

        XCTAssertEqual(pointPlaneDistance(F.planes[1], ntr), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[1], nbr), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[1], ftr), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[1], fbr), 0, accuracy: eps)

        XCTAssertEqual(pointPlaneDistance(F.planes[2], nbl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[2], nbr), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[2], fbl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[2], fbr), 0, accuracy: eps)

        XCTAssertEqual(pointPlaneDistance(F.planes[3], ntl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[3], ntr), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[3], ftl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[3], ftr), 0, accuracy: eps)

        XCTAssertEqual(pointPlaneDistance(F.planes[4], ntl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[4], ntr), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[4], nbl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[4], nbr), 0, accuracy: eps)

        XCTAssertEqual(pointPlaneDistance(F.planes[5], ftl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[5], ftr), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[5], fbl), 0, accuracy: eps)
        XCTAssertEqual(pointPlaneDistance(F.planes[5], fbr), 0, accuracy: eps)
    }

    struct EntityAABB {
        var center: simd_float4
        var halfExtent: simd_float4
        var index: UInt32
        var version: UInt32
        var pad0: UInt32
        var pad1: UInt32
    }

    func test_kernel_matches_cpu_reference() {
        // Frustum planes (nx,ny,nz,d). Keep it simple & deterministic.
        let planes: [simd_float4] = [
            simd_float4(1, 0, 0, 1), // x >= -1
            simd_float4(-1, 0, 0, 1), // x <=  1
            simd_float4(0, 1, 0, 1), // y >= -1
            simd_float4(0, -1, 0, 1), // y <=  1
            simd_float4(0, 0, 1, 1), // z >= -1
            simd_float4(0, 0, -1, 5), // z <=  5
        ]

        // Synthetic AABBs (already in world space center/extent)
        let a0 = EntityAABB(center: simd_float4(0, 0, 0, 0), halfExtent: simd_float4(0.5, 0.5, 0.5, 0), index: 10, version: 1, pad0: 0, pad1: 0) // inside
        let a1 = EntityAABB(center: simd_float4(-5, 0, 0, 0), halfExtent: simd_float4(0.5, 0.5, 0.5, 0), index: 11, version: 1, pad0: 0, pad1: 0) // outside left
        let a2 = EntityAABB(center: simd_float4(0, 0, -1, 0), halfExtent: simd_float4(0.5, 0.5, 0.5, 0), index: 12, version: 1, pad0: 0, pad1: 0) // touching near → inside
        let a3 = EntityAABB(center: simd_float4(0.2, 0.2, 0.2, 0), halfExtent: simd_float4(0, 0, 0, 0), index: 13, version: 7, pad0: 0, pad1: 0) // point inside
        var aabbs = [a0, a1, a2, a3]

        // CPU mask
        let expected = aabbs.map { a in
            cpuInFrustum(center: simd_float3(a.center.x, a.center.y, a.center.z),
                         extent: simd_float3(a.halfExtent.x, a.halfExtent.y, a.halfExtent.z),
                         planes: planes)
        }
        let expectedVisiblePairs = zip(aabbs, expected).compactMap { $1 ? ($0.index, $0.version) : nil }

        // Buffers
        let aabbBuf = renderInfo.device.makeBuffer(bytes: &aabbs, length: MemoryLayout<EntityAABB>.stride * aabbs.count)!
        let planesBuf = renderInfo.device.makeBuffer(length: MemoryLayout<simd_float4>.stride * 6, options: [])!
        let visibleCountBuf = renderInfo.device.makeBuffer(length: MemoryLayout<UInt32>.stride, options: [])!
        let visBuf = renderInfo.device.makeBuffer(length: MemoryLayout<VisibleEntity>.stride * aabbs.count, options: [])!

        // Zero visible count
        memset(visibleCountBuf.contents(), 0, MemoryLayout<UInt32>.stride)

        // Dispatch
        let cmd = renderInfo.commandQueue.makeCommandBuffer()!

        _ = dispatchFrustumCull(
            cmd,
            pipeline: frustumCullingPipeline.pipelineState!,
            frustumPlanes: planes,
            aabbs: aabbBuf,
            aabbCount: aabbs.count,
            visibleCountBuffer: visibleCountBuf,
            visibilityBuffer: visBuf,
            planesBuffer: planesBuf
        )

        cmd.commit()
        cmd.waitUntilCompleted()

        // Readback
        let visibleCount = visibleCountBuf.contents().load(as: UInt32.self)
        let vptr = visBuf.contents().bindMemory(to: VisibleEntity.self, capacity: Int(visibleCount))
        var gpuPairs: [(UInt32, UInt32)] = []
        for i in 0 ..< Int(visibleCount) {
            gpuPairs.append((vptr[i].index, vptr[i].version))
        }

        XCTAssertEqual(Int(visibleCount), expectedVisiblePairs.count)
    }
}
