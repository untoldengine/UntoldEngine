//
//  RenderExtensionPlugins.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Identifies the rendering-extension contract understood by the engine and a plugin.
public struct RenderExtensionAPIVersion: RawRepresentable, Hashable, Codable, Comparable, Sendable {
    /// The extension API implemented by this engine build.
    public static let current = RenderExtensionAPIVersion(1)

    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static func < (lhs: RenderExtensionAPIVersion, rhs: RenderExtensionAPIVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A plugin's release version.
public struct RenderExtensionPluginVersion: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public let major: UInt32
    public let minor: UInt32
    public let patch: UInt32

    public init(major: UInt32, minor: UInt32, patch: UInt32) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (
        lhs: RenderExtensionPluginVersion,
        rhs: RenderExtensionPluginVersion
    ) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}

/// Declares a plugin's stable identity, release version, and required engine contract.
public struct RenderExtensionPluginManifest: Hashable, Codable, Sendable {
    public let id: String
    public let displayName: String
    public let version: RenderExtensionPluginVersion
    public let requiredAPIVersion: RenderExtensionAPIVersion

    public init(
        id: String,
        displayName: String,
        version: RenderExtensionPluginVersion,
        requiredAPIVersion: RenderExtensionAPIVersion = .current
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.requiredAPIVersion = requiredAPIVersion
    }
}

/// A statically linked package or framework that provides one or more rendering extensions.
public protocol RenderExtensionPlugin: Sendable {
    var manifest: RenderExtensionPluginManifest { get }

    /// Creates the extensions supplied by this plugin for contract validation or installation.
    func makeRenderExtensions() -> [any RenderExtension]
}

/// Describes a violation of the rendering-extension plugin contract.
public enum RenderExtensionPluginValidationError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyPluginID
    case pluginIDMustBeNamespaced(String)
    case emptyDisplayName(pluginID: String)
    case unsupportedAPIVersion(
        pluginID: String,
        required: RenderExtensionAPIVersion,
        supported: RenderExtensionAPIVersion
    )
    case noExtensions(pluginID: String)
    case emptyExtensionID(pluginID: String)
    case duplicateExtensionID(pluginID: String, extensionID: String)
    case extensionIDOutsidePluginNamespace(pluginID: String, extensionID: String)
    case duplicatePluginID(String)

    public var description: String {
        switch self {
        case .emptyPluginID:
            return "Render extension plugin IDs cannot be empty"
        case let .pluginIDMustBeNamespaced(id):
            return "Render extension plugin ID '\(id)' must be a dot-separated package namespace"
        case let .emptyDisplayName(pluginID):
            return "Render extension plugin '\(pluginID)' must provide a display name"
        case let .unsupportedAPIVersion(pluginID, required, supported):
            return "Render extension plugin '\(pluginID)' requires API version \(required.rawValue), but the engine supports version \(supported.rawValue)"
        case let .noExtensions(pluginID):
            return "Render extension plugin '\(pluginID)' does not provide any extensions"
        case let .emptyExtensionID(pluginID):
            return "Render extension plugin '\(pluginID)' contains an extension with an empty ID"
        case let .duplicateExtensionID(pluginID, extensionID):
            return "Render extension plugin '\(pluginID)' provides extension ID '\(extensionID)' more than once"
        case let .extensionIDOutsidePluginNamespace(pluginID, extensionID):
            return "Render extension ID '\(extensionID)' must equal or begin with plugin namespace '\(pluginID)'"
        case let .duplicatePluginID(pluginID):
            return "Render extension plugin ID '\(pluginID)' is declared more than once"
        }
    }
}

/// The complete deterministic result of validating one or more plugin contracts.
public struct RenderExtensionPluginValidationReport: Equatable, Sendable {
    public let errors: [RenderExtensionPluginValidationError]

    public init(errors: [RenderExtensionPluginValidationError]) {
        self.errors = errors
    }

    public var isValid: Bool {
        errors.isEmpty
    }
}

/// Validates plugin metadata and extension identity without registering engine artifacts.
public enum RenderExtensionPluginValidator {
    /// Validates one plugin against the extension API supported by the engine.
    public static func validate(
        _ plugin: any RenderExtensionPlugin,
        supportedAPIVersion: RenderExtensionAPIVersion = .current
    ) -> RenderExtensionPluginValidationReport {
        validate(
            manifest: plugin.manifest,
            extensions: plugin.makeRenderExtensions(),
            supportedAPIVersion: supportedAPIVersion
        )
    }

    /// Validates a plugin collection, including duplicate plugin identities.
    public static func validate(
        _ plugins: [any RenderExtensionPlugin],
        supportedAPIVersion: RenderExtensionAPIVersion = .current
    ) -> RenderExtensionPluginValidationReport {
        var errors: [RenderExtensionPluginValidationError] = []
        var seenPluginIDs: Set<String> = []
        var duplicatePluginIDs: Set<String> = []

        for plugin in plugins {
            let manifest = plugin.manifest
            let pluginID = manifest.id
            let renderExtensions = plugin.makeRenderExtensions()
            errors.append(contentsOf: validate(
                manifest: manifest,
                extensions: renderExtensions,
                supportedAPIVersion: supportedAPIVersion
            ).errors)
            let trimmedPluginID = pluginID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPluginID.isEmpty,
               !seenPluginIDs.insert(pluginID).inserted,
               duplicatePluginIDs.insert(pluginID).inserted
            {
                errors.append(.duplicatePluginID(pluginID))
            }
        }

        return RenderExtensionPluginValidationReport(errors: errors)
    }

    static func validate(
        manifest: RenderExtensionPluginManifest,
        extensions: [any RenderExtension],
        supportedAPIVersion: RenderExtensionAPIVersion = .current
    ) -> RenderExtensionPluginValidationReport {
        let pluginID = manifest.id
        let trimmedPluginID = pluginID.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidPluginID = isValidNamespace(pluginID)
        var errors: [RenderExtensionPluginValidationError] = []

        if trimmedPluginID.isEmpty {
            appendUnique(.emptyPluginID, to: &errors)
        } else if !hasValidPluginID {
            appendUnique(.pluginIDMustBeNamespaced(pluginID), to: &errors)
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
        if extensions.isEmpty {
            errors.append(.noExtensions(pluginID: pluginID))
            return RenderExtensionPluginValidationReport(errors: errors)
        }

        var seenExtensionIDs: Set<String> = []
        for renderExtension in extensions {
            let extensionID = renderExtension.id
            if extensionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendUnique(.emptyExtensionID(pluginID: pluginID), to: &errors)
                continue
            }
            if !seenExtensionIDs.insert(extensionID).inserted {
                appendUnique(
                    .duplicateExtensionID(pluginID: pluginID, extensionID: extensionID),
                    to: &errors
                )
            }
            if hasValidPluginID,
               extensionID != pluginID,
               !extensionID.hasPrefix("\(pluginID).")
            {
                errors.append(
                    .extensionIDOutsidePluginNamespace(
                        pluginID: pluginID,
                        extensionID: extensionID
                    )
                )
            }
        }
        return RenderExtensionPluginValidationReport(errors: errors)
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

    private static func appendUnique(
        _ error: RenderExtensionPluginValidationError,
        to errors: inout [RenderExtensionPluginValidationError]
    ) {
        if !errors.contains(error) {
            errors.append(error)
        }
    }
}

/// Associates a failed extension registration with its plugin member ID.
public struct RenderExtensionPluginExtensionFailure: Equatable, Sendable {
    public let extensionID: String
    public let result: RenderExtensionRegistrationResult

    public init(extensionID: String, result: RenderExtensionRegistrationResult) {
        self.extensionID = extensionID
        self.result = result
    }
}

/// Collects contract, ownership, artifact, and graph failures for a plugin transaction.
public struct RenderExtensionPluginFailure: Equatable, Sendable {
    public let validationErrors: [RenderExtensionPluginValidationError]
    public let conflictingExtensionIDs: [String]
    public let extensionFailures: [RenderExtensionPluginExtensionFailure]
    public let artifactConflicts: [RenderExtensionArtifactConflict]
    public let graphValidationErrors: [RenderGraphError]

    public init(
        validationErrors: [RenderExtensionPluginValidationError] = [],
        conflictingExtensionIDs: [String] = [],
        extensionFailures: [RenderExtensionPluginExtensionFailure] = [],
        artifactConflicts: [RenderExtensionArtifactConflict] = [],
        graphValidationErrors: [RenderGraphError] = []
    ) {
        self.validationErrors = validationErrors
        self.conflictingExtensionIDs = conflictingExtensionIDs
        self.extensionFailures = extensionFailures
        self.artifactConflicts = artifactConflicts
        self.graphValidationErrors = graphValidationErrors
    }
}

/// Reports whether a plugin was installed, replaced, or rejected atomically.
public enum RenderExtensionPluginInstallationResult: Equatable, Sendable {
    case installed
    case replaced
    case rejected(RenderExtensionPluginFailure)
}

private struct InstalledRenderExtensionPlugin {
    let manifest: RenderExtensionPluginManifest
    let extensions: [any RenderExtension]
}

/// Installs and removes complete rendering-extension plugins as serialized transactions.
public final class RenderExtensionPluginRegistry: @unchecked Sendable {
    public static let shared = RenderExtensionPluginRegistry()

    private let lock = NSLock()
    private var pluginsByID: [String: InstalledRenderExtensionPlugin] = [:]
    private var pluginOrder: [String] = []
    private var pluginIDByExtensionID: [String: String] = [:]
    private var failuresByPluginID: [String: RenderExtensionPluginFailure] = [:]

    private init() {}

    /// Validates and atomically installs or replaces a plugin.
    @discardableResult
    public func install(
        _ plugin: any RenderExtensionPlugin
    ) -> RenderExtensionPluginInstallationResult {
        let manifest = plugin.manifest
        let extensions = plugin.makeRenderExtensions()
        let validation = RenderExtensionPluginValidator.validate(
            manifest: manifest,
            extensions: extensions
        )
        guard validation.isValid else {
            let failure = RenderExtensionPluginFailure(validationErrors: validation.errors)
            storeFailure(failure, pluginID: manifest.id)
            return .rejected(failure)
        }

        return RenderExtensionRegistry.shared.performPluginLifecycle {
            installValidatedPlugin(manifest: manifest, extensions: extensions)
        }
    }

    /// Removes a plugin and every artifact owned by its extensions.
    public func uninstall(id: String) {
        RenderExtensionRegistry.shared.performPluginLifecycle {
            lock.lock()
            let installedPlugin = pluginsByID.removeValue(forKey: id)
            pluginOrder.removeAll { $0 == id }
            failuresByPluginID.removeValue(forKey: id)
            if let installedPlugin {
                for renderExtension in installedPlugin.extensions {
                    pluginIDByExtensionID.removeValue(forKey: renderExtension.id)
                }
            }
            lock.unlock()

            for renderExtension in installedPlugin?.extensions ?? [] {
                RenderExtensionRegistry.shared.unregisterPluginOwnedExtension(
                    id: renderExtension.id
                )
            }
        }
    }

    /// Removes all installed plugins without removing standalone extensions.
    public func removeAll() {
        RenderExtensionRegistry.shared.performPluginLifecycle {
            lock.lock()
            let installedPlugins = pluginOrder.compactMap { pluginsByID[$0] }
            pluginsByID.removeAll()
            pluginOrder.removeAll()
            pluginIDByExtensionID.removeAll()
            failuresByPluginID.removeAll()
            lock.unlock()

            for installedPlugin in installedPlugins {
                for renderExtension in installedPlugin.extensions {
                    RenderExtensionRegistry.shared.unregisterPluginOwnedExtension(
                        id: renderExtension.id
                    )
                }
            }
        }
    }

    public func installedPluginIDs() -> [String] {
        lock.lock()
        let ids = pluginOrder
        lock.unlock()
        return ids
    }

    public func installedManifests() -> [RenderExtensionPluginManifest] {
        lock.lock()
        let manifests = pluginOrder.compactMap { pluginsByID[$0]?.manifest }
        lock.unlock()
        return manifests
    }

    public func failure(forPluginID id: String) -> RenderExtensionPluginFailure? {
        lock.lock()
        let failure = failuresByPluginID[id]
        lock.unlock()
        return failure
    }

    func installedPluginID(containingExtensionID extensionID: String) -> String? {
        lock.lock()
        let pluginID = pluginIDByExtensionID[extensionID]
        lock.unlock()
        return pluginID
    }

    func removeAllMetadata() {
        lock.lock()
        pluginsByID.removeAll()
        pluginOrder.removeAll()
        pluginIDByExtensionID.removeAll()
        failuresByPluginID.removeAll()
        lock.unlock()
    }

    func invalidateInstalledPlugin(
        containingExtensionID extensionID: String,
        artifactConflicts: [RenderExtensionArtifactConflict] = [],
        shaderLibraryErrors: [RenderShaderLibraryLoadingError] = [],
        pipelineErrors: [RenderExtensionPipelineError] = [],
        graphValidationErrors: [RenderGraphError] = []
    ) -> [String] {
        lock.lock()
        guard let pluginID = pluginIDByExtensionID[extensionID],
              let installedPlugin = pluginsByID.removeValue(forKey: pluginID)
        else {
            lock.unlock()
            return []
        }
        let extensionIDs = installedPlugin.extensions.map(\.id)
        pluginOrder.removeAll { $0 == pluginID }
        for ownedExtensionID in extensionIDs {
            pluginIDByExtensionID.removeValue(forKey: ownedExtensionID)
        }
        let extensionFailures: [RenderExtensionPluginExtensionFailure]
        if shaderLibraryErrors.isEmpty, pipelineErrors.isEmpty {
            extensionFailures = []
        } else {
            extensionFailures = [
                RenderExtensionPluginExtensionFailure(
                    extensionID: extensionID,
                    result: .rejectedArtifacts(
                        conflicts: artifactConflicts,
                        shaderLibraryErrors: shaderLibraryErrors,
                        pipelineErrors: pipelineErrors,
                        resourceValidationErrors: []
                    )
                ),
            ]
        }
        failuresByPluginID[pluginID] = RenderExtensionPluginFailure(
            extensionFailures: extensionFailures,
            artifactConflicts: artifactConflicts,
            graphValidationErrors: graphValidationErrors
        )
        lock.unlock()
        return extensionIDs
    }

    private func installValidatedPlugin(
        manifest: RenderExtensionPluginManifest,
        extensions: [any RenderExtension]
    ) -> RenderExtensionPluginInstallationResult {
        lock.lock()
        let previousPlugin = pluginsByID[manifest.id]
        lock.unlock()

        let previousExtensionIDs = Set(previousPlugin?.extensions.map(\.id) ?? [])
        let newExtensionIDs = extensions.map(\.id)
        let registeredExtensionIDs = Set(RenderExtensionRegistry.shared.registeredIDs())
        let conflictingExtensionIDs = newExtensionIDs.filter {
            registeredExtensionIDs.contains($0) && !previousExtensionIDs.contains($0)
        }
        guard conflictingExtensionIDs.isEmpty else {
            let failure = RenderExtensionPluginFailure(
                conflictingExtensionIDs: conflictingExtensionIDs
            )
            storeFailure(failure, pluginID: manifest.id)
            return .rejected(failure)
        }

        let previousGlobalOrder = RenderExtensionRegistry.shared.registeredIDs()
        let newExtensionIDSet = Set(newExtensionIDs)
        let removedPreviousExtensions = previousPlugin?.extensions.filter {
            !newExtensionIDSet.contains($0.id)
        } ?? []
        for renderExtension in removedPreviousExtensions {
            RenderExtensionRegistry.shared.unregisterPluginOwnedExtension(id: renderExtension.id)
        }

        var successfullyRegisteredIDs: [String] = []
        for renderExtension in extensions {
            let result = RenderExtensionRegistry.shared.registerPluginOwnedExtension(renderExtension)
            guard result == .registered else {
                rollbackFailedInstallation(
                    previousPlugin: previousPlugin,
                    previousGlobalOrder: previousGlobalOrder,
                    successfullyRegisteredIDs: successfullyRegisteredIDs
                )
                let failure = RenderExtensionPluginFailure(
                    extensionFailures: [
                        RenderExtensionPluginExtensionFailure(
                            extensionID: renderExtension.id,
                            result: result
                        ),
                    ]
                )
                storeFailure(failure, pluginID: manifest.id)
                return .rejected(failure)
            }
            successfullyRegisteredIDs.append(renderExtension.id)
        }

        let desiredGlobalOrder = replacingPluginExtensionIDs(
            previousExtensionIDs: previousExtensionIDs,
            newExtensionIDs: newExtensionIDs,
            in: previousGlobalOrder
        )
        RenderExtensionRegistry.shared.setRegisteredExtensionOrder(desiredGlobalOrder)

        lock.lock()
        if previousPlugin == nil {
            pluginOrder.append(manifest.id)
        }
        if let previousPlugin {
            for renderExtension in previousPlugin.extensions {
                pluginIDByExtensionID.removeValue(forKey: renderExtension.id)
            }
        }
        pluginsByID[manifest.id] = InstalledRenderExtensionPlugin(
            manifest: manifest,
            extensions: extensions
        )
        for renderExtension in extensions {
            pluginIDByExtensionID[renderExtension.id] = manifest.id
        }
        failuresByPluginID.removeValue(forKey: manifest.id)
        lock.unlock()
        return previousPlugin == nil ? .installed : .replaced
    }

    private func rollbackFailedInstallation(
        previousPlugin: InstalledRenderExtensionPlugin?,
        previousGlobalOrder: [String],
        successfullyRegisteredIDs: [String]
    ) {
        let previousExtensionsByID = Dictionary(
            uniqueKeysWithValues: (previousPlugin?.extensions ?? []).map { ($0.id, $0) }
        )
        for extensionID in successfullyRegisteredIDs where previousExtensionsByID[extensionID] == nil {
            RenderExtensionRegistry.shared.unregisterPluginOwnedExtension(id: extensionID)
        }
        for renderExtension in previousPlugin?.extensions ?? [] {
            _ = RenderExtensionRegistry.shared.registerPluginOwnedExtension(renderExtension)
        }
        RenderExtensionRegistry.shared.setRegisteredExtensionOrder(previousGlobalOrder)
    }

    private func replacingPluginExtensionIDs(
        previousExtensionIDs: Set<String>,
        newExtensionIDs: [String],
        in globalOrder: [String]
    ) -> [String] {
        guard !previousExtensionIDs.isEmpty else {
            return globalOrder + newExtensionIDs
        }
        let insertionIndex = globalOrder.prefix { !previousExtensionIDs.contains($0) }.count
        var result = globalOrder.filter { !previousExtensionIDs.contains($0) }
        result.insert(contentsOf: newExtensionIDs, at: min(insertionIndex, result.count))
        return result
    }

    private func storeFailure(_ failure: RenderExtensionPluginFailure, pluginID: String) {
        lock.lock()
        failuresByPluginID[pluginID] = failure
        lock.unlock()
    }
}
