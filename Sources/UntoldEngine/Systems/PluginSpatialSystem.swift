//
//  PluginSpatialSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public struct PluginSpatialObjectID: Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        rawValue = value
    }
}

public struct PluginSpatialRay: Sendable {
    public let origin: simd_float3
    public let direction: simd_float3

    public init(origin: simd_float3, direction: simd_float3) {
        self.origin = origin
        self.direction = direction
    }
}

public struct PluginSpatialQueryOptions: Sendable {
    public var maxDistance: Float

    public init(maxDistance: Float = .greatestFiniteMagnitude) {
        self.maxDistance = maxDistance
    }
}

public struct PluginSpatialBounds: Sendable {
    public let ownerID: String
    public let objectID: PluginSpatialObjectID
    public let entityId: EntityID?
    public let bounds: AABB

    public init(
        ownerID: String,
        objectID: PluginSpatialObjectID,
        entityId: EntityID? = nil,
        bounds: AABB
    ) {
        self.ownerID = ownerID
        self.objectID = objectID
        self.entityId = entityId
        self.bounds = bounds
    }
}

public struct PluginSpatialHit: Sendable {
    public let ownerID: String
    public let objectID: PluginSpatialObjectID
    public let entityId: EntityID?
    public let distance: Float
    public let worldPosition: simd_float3
    public let worldNormal: simd_float3?

    public init(
        ownerID: String,
        objectID: PluginSpatialObjectID,
        entityId: EntityID? = nil,
        distance: Float,
        worldPosition: simd_float3,
        worldNormal: simd_float3? = nil
    ) {
        self.ownerID = ownerID
        self.objectID = objectID
        self.entityId = entityId
        self.distance = distance
        self.worldPosition = worldPosition
        self.worldNormal = worldNormal
    }
}

public protocol PluginSpatialProvider: AnyObject, Sendable {
    var ownerID: String { get }

    /// Returns the provider's current world-space bounds.
    func boundsSnapshot() -> [PluginSpatialBounds]

    /// Returns world-space hits for this provider.
    func raycast(_ ray: PluginSpatialRay, options: PluginSpatialQueryOptions) -> [PluginSpatialHit]
}

public extension PluginSpatialProvider {
    func raycast(_ ray: PluginSpatialRay, options: PluginSpatialQueryOptions) -> [PluginSpatialHit] {
        PluginSpatialRegistry.raycastBounds(
            boundsSnapshot(),
            ray: ray,
            options: options
        )
    }
}

public enum PluginSpatialProviderRegistrationResult: Equatable, Sendable {
    case installed
    case duplicateOwnerID(String)
}

public final class PluginSpatialRegistry: @unchecked Sendable {
    public static let shared = PluginSpatialRegistry()

    private let accessLock = NSRecursiveLock()
    private var providersByOwnerID: [String: PluginSpatialProvider] = [:]

    private init() {}

    @discardableResult
    public func register(_ provider: PluginSpatialProvider) -> PluginSpatialProviderRegistrationResult {
        accessLock.lock()
        defer { accessLock.unlock() }

        guard providersByOwnerID[provider.ownerID] == nil else {
            return .duplicateOwnerID(provider.ownerID)
        }

        providersByOwnerID[provider.ownerID] = provider
        return .installed
    }

    public func unregister(ownerID: String) {
        accessLock.lock()
        providersByOwnerID.removeValue(forKey: ownerID)
        accessLock.unlock()
    }

    public func removeAll() {
        accessLock.lock()
        providersByOwnerID.removeAll()
        accessLock.unlock()
    }

    public func boundsSnapshot() -> [PluginSpatialBounds] {
        accessLock.lock()
        let providers = Array(providersByOwnerID.values)
        accessLock.unlock()

        return providers.flatMap { $0.boundsSnapshot() }
    }

    public func query(range: AABB) -> [PluginSpatialBounds] {
        boundsSnapshot().filter { $0.bounds.intersects(range) }
    }

    public func query(sphere: BoundingSphere) -> [PluginSpatialBounds] {
        boundsSnapshot().filter { $0.bounds.intersects(sphere) }
    }

    public func raycastAll(
        rayOrigin: simd_float3,
        rayDirection: simd_float3,
        options: PluginSpatialQueryOptions = PluginSpatialQueryOptions()
    ) -> [PluginSpatialHit] {
        let rayLengthSquared = simd_length_squared(rayDirection)
        guard rayLengthSquared.isFinite, rayLengthSquared > Float.ulpOfOne else { return [] }

        let ray = PluginSpatialRay(
            origin: rayOrigin,
            direction: rayDirection / sqrt(rayLengthSquared)
        )

        accessLock.lock()
        let providers = Array(providersByOwnerID.values)
        accessLock.unlock()

        return providers
            .flatMap { $0.raycast(ray, options: options) }
            .filter { $0.distance <= options.maxDistance }
            .sorted { $0.distance < $1.distance }
    }

    public func raycast(
        rayOrigin: simd_float3,
        rayDirection: simd_float3,
        options: PluginSpatialQueryOptions = PluginSpatialQueryOptions()
    ) -> PluginSpatialHit? {
        raycastAll(rayOrigin: rayOrigin, rayDirection: rayDirection, options: options).first
    }

    static func raycastBounds(
        _ bounds: [PluginSpatialBounds],
        ray: PluginSpatialRay,
        options: PluginSpatialQueryOptions
    ) -> [PluginSpatialHit] {
        bounds.compactMap { item in
            guard let distance = rayAABBIntersectionDistance(
                rayOrigin: ray.origin,
                rayDirection: ray.direction,
                minBounds: simd_min(item.bounds.min, item.bounds.max),
                maxBounds: simd_max(item.bounds.min, item.bounds.max)
            ) else {
                return nil
            }

            guard distance <= options.maxDistance else { return nil }
            return PluginSpatialHit(
                ownerID: item.ownerID,
                objectID: item.objectID,
                entityId: item.entityId,
                distance: distance,
                worldPosition: ray.origin + ray.direction * distance
            )
        }
        .sorted { $0.distance < $1.distance }
    }
}
