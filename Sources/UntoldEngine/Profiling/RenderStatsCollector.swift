//
//  RenderStatsCollector.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import Metal

public enum RenderDrawCategory {
    case opaque
    case transparent
    case shadow
    case other
}

public struct RenderDrawStats {
    public var drawCallsTotal: Int = 0
    public var drawCallsOpaque: Int = 0
    public var drawCallsTransparent: Int = 0
    public var drawCallsShadow: Int = 0
    public var drawCallsBatched: Int = 0
    public var trianglesTotal: Int = 0
}

public final class RenderStatsCollector {
    public static let shared = RenderStatsCollector()

    #if ENGINE_STATS_ENABLED
        private let lock = NSLock()
        private var stats = RenderDrawStats()
    #endif

    private init() {}

    public func reset() {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            stats = .init()
            lock.unlock()
        #endif
    }

    public func snapshot() -> RenderDrawStats {
        #if ENGINE_STATS_ENABLED
            lock.lock()
            let result = stats
            lock.unlock()
            return result
        #else
            return .init()
        #endif
    }

    func recordIndexedDraw(
        type: MTLPrimitiveType,
        indexCount: Int,
        instanceCount: Int = 1,
        category: RenderDrawCategory = .other,
        batched: Bool = false
    ) {
        recordDraw(
            primitiveType: type,
            elementCount: indexCount,
            instanceCount: instanceCount,
            category: category,
            batched: batched
        )
    }

    func recordPrimitiveDraw(
        type: MTLPrimitiveType,
        vertexCount: Int,
        instanceCount: Int = 1,
        category: RenderDrawCategory = .other,
        batched: Bool = false
    ) {
        recordDraw(
            primitiveType: type,
            elementCount: vertexCount,
            instanceCount: instanceCount,
            category: category,
            batched: batched
        )
    }

    private func recordDraw(
        primitiveType: MTLPrimitiveType,
        elementCount: Int,
        instanceCount: Int,
        category: RenderDrawCategory,
        batched: Bool
    ) {
        #if ENGINE_STATS_ENABLED
            let safeElementCount = max(0, elementCount)
            let safeInstanceCount = max(1, instanceCount)
            let triangles = triangleCount(for: primitiveType, elementCount: safeElementCount) * safeInstanceCount

            lock.lock()
            stats.drawCallsTotal += 1
            stats.trianglesTotal += triangles
            if batched {
                stats.drawCallsBatched += 1
            }

            switch category {
            case .opaque:
                stats.drawCallsOpaque += 1
            case .transparent:
                stats.drawCallsTransparent += 1
            case .shadow:
                stats.drawCallsShadow += 1
            case .other:
                break
            }
            lock.unlock()
        #else
            _ = primitiveType
            _ = elementCount
            _ = instanceCount
            _ = category
            _ = batched
        #endif
    }

    private func triangleCount(for primitiveType: MTLPrimitiveType, elementCount: Int) -> Int {
        switch primitiveType {
        case .triangle:
            return elementCount / 3
        case .triangleStrip:
            return max(0, elementCount - 2)
        default:
            return 0
        }
    }
}

public extension MTLRenderCommandEncoder {
    @inline(__always)
    func drawIndexedPrimitivesTracked(
        type: MTLPrimitiveType,
        indexCount: Int,
        indexType: MTLIndexType,
        indexBuffer: MTLBuffer,
        indexBufferOffset: Int,
        category: RenderDrawCategory = .other,
        batched: Bool = false
    ) {
        drawIndexedPrimitives(
            type: type,
            indexCount: indexCount,
            indexType: indexType,
            indexBuffer: indexBuffer,
            indexBufferOffset: indexBufferOffset
        )
        #if ENGINE_STATS_ENABLED
            RenderStatsCollector.shared.recordIndexedDraw(
                type: type,
                indexCount: indexCount,
                category: category,
                batched: batched
            )
        #else
            _ = category
            _ = batched
        #endif
    }

    @inline(__always)
    func drawPrimitivesTracked(
        type: MTLPrimitiveType,
        vertexStart: Int,
        vertexCount: Int,
        category: RenderDrawCategory = .other,
        batched: Bool = false
    ) {
        drawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount)
        #if ENGINE_STATS_ENABLED
            RenderStatsCollector.shared.recordPrimitiveDraw(
                type: type,
                vertexCount: vertexCount,
                category: category,
                batched: batched
            )
        #else
            _ = category
            _ = batched
        #endif
    }

    @inline(__always)
    func drawPrimitivesTracked(
        type: MTLPrimitiveType,
        vertexStart: Int,
        vertexCount: Int,
        instanceCount: Int,
        category: RenderDrawCategory = .other,
        batched: Bool = false
    ) {
        drawPrimitives(type: type, vertexStart: vertexStart, vertexCount: vertexCount, instanceCount: instanceCount)
        #if ENGINE_STATS_ENABLED
            RenderStatsCollector.shared.recordPrimitiveDraw(
                type: type,
                vertexCount: vertexCount,
                instanceCount: instanceCount,
                category: category,
                batched: batched
            )
        #else
            _ = category
            _ = batched
        #endif
    }
}
