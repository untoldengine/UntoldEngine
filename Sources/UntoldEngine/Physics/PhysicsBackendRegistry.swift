//
//  PhysicsBackendRegistry.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Identifies the physics-backend contract understood by the engine and a plugin.
public struct PhysicsBackendAPIVersion: RawRepresentable, Hashable, Codable, Comparable, Sendable {
    /// The backend API implemented by this engine build.
    public static let current = PhysicsBackendAPIVersion(1)

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static func < (lhs: PhysicsBackendAPIVersion, rhs: PhysicsBackendAPIVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A backend plugin's release version.
public struct PhysicsBackendVersion: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public let major: UInt32
    public let minor: UInt32
    public let patch: UInt32

    public init(major: UInt32, minor: UInt32, patch: UInt32) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (lhs: PhysicsBackendVersion, rhs: PhysicsBackendVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}

/// Declares a physics backend plugin's stable identity, release version, and required engine contract.
public struct PhysicsBackendPluginManifest: Hashable, Codable, Sendable {
    public let id: String
    public let displayName: String
    public let version: PhysicsBackendVersion
    public let requiredAPIVersion: PhysicsBackendAPIVersion

    public init(
        id: String,
        displayName: String,
        version: PhysicsBackendVersion,
        requiredAPIVersion: PhysicsBackendAPIVersion = .current
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.requiredAPIVersion = requiredAPIVersion
    }
}

/// A statically linked package or framework that provides a physics backend.
public protocol PhysicsBackendPlugin: Sendable {
    var manifest: PhysicsBackendPluginManifest { get }

    /// Creates the backend supplied by this plugin for contract validation or installation.
    func makeBackend() -> any PhysicsBackend
}

/// Describes a violation of the physics-backend plugin contract.
public enum PhysicsBackendPluginValidationError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyPluginID
    case pluginIDMustBeNamespaced(String)
    case emptyDisplayName(pluginID: String)
    case unsupportedAPIVersion(
        pluginID: String,
        required: PhysicsBackendAPIVersion,
        supported: PhysicsBackendAPIVersion
    )
    case emptyBackendID(pluginID: String)
    case backendIDOutsidePluginNamespace(pluginID: String, backendID: String)

    public var description: String {
        switch self {
        case .emptyPluginID:
            return "Physics backend plugin IDs cannot be empty"
        case let .pluginIDMustBeNamespaced(id):
            return "Physics backend plugin ID '\(id)' must be a dot-separated package namespace"
        case let .emptyDisplayName(pluginID):
            return "Physics backend plugin '\(pluginID)' must provide a display name"
        case let .unsupportedAPIVersion(pluginID, required, supported):
            return "Physics backend plugin '\(pluginID)' requires API version \(required.rawValue), but the engine supports version \(supported.rawValue)"
        case let .emptyBackendID(pluginID):
            return "Physics backend plugin '\(pluginID)' provides a backend with an empty ID"
        case let .backendIDOutsidePluginNamespace(pluginID, backendID):
            return "Physics backend ID '\(backendID)' must equal or begin with plugin namespace '\(pluginID)'"
        }
    }
}

/// Validates plugin metadata and backend identity without installing anything.
public enum PhysicsBackendPluginValidator {
    public static func validate(
        _ plugin: any PhysicsBackendPlugin,
        supportedAPIVersion: PhysicsBackendAPIVersion = .current
    ) -> [PhysicsBackendPluginValidationError] {
        validate(
            manifest: plugin.manifest,
            backendID: plugin.makeBackend().id,
            supportedAPIVersion: supportedAPIVersion
        )
    }

    static func validate(
        manifest: PhysicsBackendPluginManifest,
        backendID: String,
        supportedAPIVersion: PhysicsBackendAPIVersion = .current
    ) -> [PhysicsBackendPluginValidationError] {
        let pluginID = manifest.id
        let trimmedPluginID = pluginID.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidPluginID = isValidNamespace(pluginID)
        var errors: [PhysicsBackendPluginValidationError] = []

        if trimmedPluginID.isEmpty {
            errors.append(.emptyPluginID)
        } else if !hasValidPluginID {
            errors.append(.pluginIDMustBeNamespaced(pluginID))
        }
        if manifest.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyDisplayName(pluginID: pluginID))
        }
        if manifest.requiredAPIVersion != supportedAPIVersion {
            errors.append(
                .unsupportedAPIVersion(
                    pluginID: pluginID,
                    required: manifest.requiredAPIVersion,
                    supported: supportedAPIVersion
                )
            )
        }
        if backendID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyBackendID(pluginID: pluginID))
        } else if hasValidPluginID,
                  backendID != pluginID,
                  !backendID.hasPrefix("\(pluginID).")
        {
            errors.append(
                .backendIDOutsidePluginNamespace(pluginID: pluginID, backendID: backendID)
            )
        }
        return errors
    }

    private static func isValidNamespace(_ id: String) -> Bool {
        guard id == id.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        let components = id.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 2 else { return false }
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return components.allSatisfy { component in
            !component.isEmpty && component.unicodeScalars.allSatisfy(allowedCharacters.contains)
        }
    }
}

/// Collects the reasons a plugin installation was rejected.
public struct PhysicsBackendPluginFailure: Equatable, Sendable {
    public let validationErrors: [PhysicsBackendPluginValidationError]
    /// Set when a different backend plugin is already installed.
    public let conflictingPluginID: String?
    /// Set when the registry was locked for runtime before the call.
    public let registryLocked: Bool

    public init(
        validationErrors: [PhysicsBackendPluginValidationError] = [],
        conflictingPluginID: String? = nil,
        registryLocked: Bool = false
    ) {
        self.validationErrors = validationErrors
        self.conflictingPluginID = conflictingPluginID
        self.registryLocked = registryLocked
    }
}

/// Reports whether a backend plugin was installed, replaced, or rejected atomically.
public enum PhysicsBackendInstallationResult: Equatable, Sendable {
    case installed
    case replaced
    case rejected(PhysicsBackendPluginFailure)
}

private struct InstalledPhysicsBackendPlugin {
    let manifest: PhysicsBackendPluginManifest
    let backend: any PhysicsBackend
}

/// Installs and removes the optional physics backend as serialized transactions.
///
/// At most one external backend is active at a time. Installing a plugin whose ID
/// matches the active one replaces it; installing a different plugin while one is
/// active is rejected — uninstall first. When no plugin is installed the engine
/// uses its built-in integrator, exactly as before this registry existed.
///
/// Install before `UntoldRenderer.create(...)`. The registry locks for runtime on
/// the first fixed substep the coordinator simulates with the installed backend;
/// from then on install and uninstall are rejected.
public final class PhysicsBackendRegistry: @unchecked Sendable {
    public static let shared = PhysicsBackendRegistry()

    private let lock = NSLock()
    private var installedPlugin: InstalledPhysicsBackendPlugin?
    private var failuresByPluginID: [String: PhysicsBackendPluginFailure] = [:]
    private var lockedForRuntime = false

    private init() {}

    /// Validates and atomically installs or replaces the backend plugin.
    @discardableResult
    public func install(_ plugin: any PhysicsBackendPlugin) -> PhysicsBackendInstallationResult {
        let manifest = plugin.manifest
        let backend = plugin.makeBackend()
        let validationErrors = PhysicsBackendPluginValidator.validate(
            manifest: manifest,
            backendID: backend.id
        )
        guard validationErrors.isEmpty else {
            let failure = PhysicsBackendPluginFailure(validationErrors: validationErrors)
            lock.lock()
            failuresByPluginID[manifest.id] = failure
            lock.unlock()
            return .rejected(failure)
        }

        lock.lock()

        guard !lockedForRuntime else {
            let failure = PhysicsBackendPluginFailure(registryLocked: true)
            failuresByPluginID[manifest.id] = failure
            lock.unlock()
            return .rejected(failure)
        }
        if let active = installedPlugin, active.manifest.id != manifest.id {
            let failure = PhysicsBackendPluginFailure(conflictingPluginID: active.manifest.id)
            failuresByPluginID[manifest.id] = failure
            lock.unlock()
            return .rejected(failure)
        }

        let replacing = installedPlugin != nil
        installedPlugin = InstalledPhysicsBackendPlugin(manifest: manifest, backend: backend)
        failuresByPluginID.removeValue(forKey: manifest.id)
        lock.unlock()

        // Outside the lock: configures the backend and schedules the coordinator
        // in EngineExtensionRegistry (idempotent for a replace of the same ID).
        PhysicsCoordinator.shared.backendDidInstall(backend)
        return replacing ? .replaced : .installed
    }

    /// Removes the backend plugin. Returns false if it is not installed or the registry is locked.
    @discardableResult
    public func uninstall(id: String) -> Bool {
        lock.lock()
        guard !lockedForRuntime, installedPlugin?.manifest.id == id else {
            lock.unlock()
            return false
        }
        installedPlugin = nil
        failuresByPluginID.removeValue(forKey: id)
        lock.unlock()

        PhysicsCoordinator.shared.backendDidUninstall()
        return true
    }

    public func activeManifest() -> PhysicsBackendPluginManifest? {
        lock.lock()
        defer { lock.unlock() }
        return installedPlugin?.manifest
    }

    public func activeBackend() -> (any PhysicsBackend)? {
        lock.lock()
        defer { lock.unlock() }
        return installedPlugin?.backend
    }

    public func failure(forPluginID id: String) -> PhysicsBackendPluginFailure? {
        lock.lock()
        defer { lock.unlock() }
        return failuresByPluginID[id]
    }

    /// Freezes the installed backend for the lifetime of the engine. Called during engine creation.
    func lockForRuntime() {
        lock.lock()
        lockedForRuntime = true
        lock.unlock()
    }

    var isLockedForRuntime: Bool {
        lock.lock()
        defer { lock.unlock() }
        return lockedForRuntime
    }

    /// Clears all state including the runtime lock. Test support only.
    func resetForTesting() {
        lock.lock()
        installedPlugin = nil
        failuresByPluginID.removeAll()
        lockedForRuntime = false
        lock.unlock()

        PhysicsCoordinator.shared.backendDidUninstall()
        PhysicsCoordinator.shared.resetForTesting()
    }
}
