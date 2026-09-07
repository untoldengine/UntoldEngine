//
//  GaussianLinkCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import Foundation
import UntoldEngine

struct GaussianLinkCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gaussian-link",
        abstract: "Link an entity of a .untold asset to a cooked .untoldgs splat payload",
        discussion: """
        Writes, removes or lists the gaussianAsset records of a .untold file (chunk 25,
        UntoldGaussianAssetRecordV1) through UntoldAssetPatcher. Every other chunk of the
        file is copied byte for byte; the string table only grows.

        The payload path is stored relative to the .untold file's directory when the
        payload sits inside or beside it, otherwise as the bare file name (with a
        warning) — the runtime resolves it next to the .untold file. The payload must be
        a version 3 .untoldgs; its splat count fills the record's single LOD level.

        Examples:
          untoldengine gaussian-link --untold Chair/chair.untold --entity 0 \\
            --payload Chair/chair.untoldgs --swap-distance 8 --in-place
          untoldengine gaussian-link --untold Chair/chair.untold --entity 0 --remove --output Chair/chair_plain.untold
          untoldengine gaussian-link --untold Chair/chair.untold --list
        """
    )

    @Option(name: .long, help: "The .untold asset to patch or list")
    var untold: String

    @Option(name: .long, help: "Entity id (the entity table's entityId) the link is set on or removed from")
    var entity: UInt32?

    @Option(name: .long, help: "The cooked .untoldgs payload to link")
    var payload: String?

    @Option(name: .customLong("swap-distance"), help: "Camera distance in metres at which the swap arms (0 = always)")
    var swapDistance: Float = 0

    @Option(name: .customLong("occluder-shrink"), help: "Metres the mesh twin's depth-only occluder shell is shrunk along its normals")
    var occluderShrink: Float = 0.02

    @Option(name: .customLong("exposure-offset"), help: "Exposure offset in EV on top of the payload's capture exposure")
    var exposureOffset: Float = 0

    @Flag(name: .customLong("in-place"), help: "Overwrite the .untold file")
    var inPlace = false

    @Option(name: .long, help: "Write the patched file here instead of overwriting the input")
    var output: String?

    @Flag(name: .long, help: "Remove the entity's link instead of setting one")
    var remove = false

    @Flag(name: .long, help: "Print the links the file carries and exit")
    var list = false

    func validate() throws {
        if list {
            guard !remove, payload == nil, !inPlace, output == nil else {
                throw ValidationError("--list takes no other option than --untold.")
            }
            return
        }
        guard entity != nil else {
            throw ValidationError("Provide --entity (or --list).")
        }
        guard inPlace != (output != nil) else {
            throw ValidationError("Provide exactly one of --in-place or --output.")
        }
        if remove {
            guard payload == nil else {
                throw ValidationError("--remove takes no --payload.")
            }
        } else {
            guard payload != nil else {
                throw ValidationError("Provide --payload, --remove or --list.")
            }
        }
    }

    func run() throws {
        let untoldURL = resolvePath(untold).standardizedFileURL
        guard FileManager.default.fileExists(atPath: untoldURL.path) else {
            throw GaussianLinkError.untoldNotFound(untoldURL.path)
        }
        let fileData = try Data(contentsOf: untoldURL)

        if list {
            for line in try Self.listing(of: fileData) {
                print(line)
            }
            return
        }

        guard let entity else { return } // validate() guarantees it
        let patched: Data
        if remove {
            patched = try Self.removing(entity: entity, from: fileData)
            printInfo("Removed the gaussianAsset link of entity \(entity)")
        } else {
            guard let payload else { return } // validate() guarantees it
            let payloadURL = resolvePath(payload).standardizedFileURL
            guard FileManager.default.fileExists(atPath: payloadURL.path) else {
                throw GaussianLinkError.payloadNotFound(payloadURL.path)
            }
            let stored = Self.storedPayloadPath(payloadURL: payloadURL, untoldURL: untoldURL)
            if !stored.isRelative {
                printWarning("\(payloadURL.path) is not inside \(untoldURL.deletingLastPathComponent().path); storing the file name \(stored.path) — keep the payload next to the .untold file")
            }
            let link = try Self.makeLink(
                payloadURL: payloadURL,
                storedPath: stored.path,
                swapDistance: swapDistance,
                occluderShrink: occluderShrink,
                exposureOffset: exposureOffset
            )
            patched = try Self.setting(link, entity: entity, in: fileData)
            printInfo("Linked entity \(entity) to \(stored.path) (\(link.lodSplatCounts.first ?? 0) splats, swap at \(swapDistance) m, shrink \(occluderShrink) m, \(exposureOffset) EV)")
        }

        let destination = output.map { resolvePath($0).standardizedFileURL } ?? untoldURL
        try patched.write(to: destination, options: .atomic)
        printSuccess("Wrote \(destination.path)")
    }

    // MARK: - Logic (kept free of ArgumentParser so tests can call it)

    /// The path written into the record: relative to the `.untold` file's directory when the
    /// payload is inside or beside it, else the bare file name.
    static func storedPayloadPath(payloadURL: URL, untoldURL: URL) -> (path: String, isRelative: Bool) {
        let directory = untoldURL.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let payload = payloadURL.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        guard payload.count > directory.count, Array(payload.prefix(directory.count)) == directory else {
            return (payloadURL.lastPathComponent, false)
        }
        return (payload.dropFirst(directory.count).joined(separator: "/"), true)
    }

    /// The link for a payload: its header (which must be version 3) fills one LOD level with
    /// the file's splat count.
    static func makeLink(
        payloadURL: URL,
        storedPath: String,
        swapDistance: Float,
        occluderShrink: Float,
        exposureOffset: Float
    ) throws -> UntoldAssetPatcher.GaussianAssetLink {
        let header: UntoldGSHeaderV3
        do {
            header = try UntoldGSFormat.readHeaderV3(from: payloadURL)
        } catch let error as UntoldGSError {
            throw GaussianLinkError.invalidPayload(payloadURL.path, error.description)
        }
        return UntoldAssetPatcher.GaussianAssetLink(
            payloadPath: storedPath,
            flags: UntoldGaussianAssetFlags.meshTwin,
            lodCount: 1,
            lodSplatCounts: [header.splatCount],
            lodSwitchScreenHeights: [0],
            occluderShrinkMeters: occluderShrink,
            exposureOffsetEV: exposureOffset,
            swapDistanceMeters: swapDistance
        )
    }

    static func setting(_ link: UntoldAssetPatcher.GaussianAssetLink, entity: UInt32, in fileData: Data) throws -> Data {
        do {
            return try UntoldAssetPatcher.settingGaussianAsset(link, onEntity: entity, in: fileData)
        } catch let error as UntoldAssetPatcher.Error {
            throw GaussianLinkError.patchFailed(error.description)
        }
    }

    static func removing(entity: UInt32, from fileData: Data) throws -> Data {
        do {
            return try UntoldAssetPatcher.removingGaussianAsset(onEntity: entity, in: fileData)
        } catch let error as UntoldAssetPatcher.Error {
            throw GaussianLinkError.patchFailed(error.description)
        }
    }

    /// One line per link, by entity id, or a single "no gaussianAsset links" line.
    static func listing(of fileData: Data) throws -> [String] {
        let links: [UInt32: UntoldAssetPatcher.GaussianAssetLink]
        do {
            links = try UntoldAssetPatcher.gaussianAssets(in: fileData)
        } catch let error as UntoldAssetPatcher.Error {
            throw GaussianLinkError.patchFailed(error.description)
        }
        guard !links.isEmpty else { return ["no gaussianAsset links"] }
        return links.keys.sorted().map { entity in
            let link = links[entity]!
            let names: [(UInt32, String)] = [
                (UntoldGaussianAssetFlags.meshTwin, "meshTwin"),
                (UntoldGaussianAssetFlags.environment, "environment"),
                (UntoldGaussianAssetFlags.windowWorld, "windowWorld"),
            ]
            let flags = names.filter { link.flags & $0.0 != 0 }.map(\.1)
            let levels = link.lodCount == 0 ? "1 level" : "\(link.lodCount) level\(link.lodCount == 1 ? "" : "s") \(link.lodSplatCounts)"
            return "entity \(entity): \(link.payloadPath) [\(flags.joined(separator: ","))] \(levels), swap \(link.swapDistanceMeters) m, shrink \(link.occluderShrinkMeters) m, \(link.exposureOffsetEV) EV"
        }
    }
}

enum GaussianLinkError: LocalizedError {
    case untoldNotFound(String)
    case payloadNotFound(String)
    case invalidPayload(String, String)
    case patchFailed(String)

    var errorDescription: String? {
        switch self {
        case let .untoldNotFound(path):
            return ".untold file does not exist: \(path)"
        case let .payloadNotFound(path):
            return "Payload does not exist: \(path)"
        case let .invalidPayload(path, reason):
            return "\(path) is not a usable .untoldgs payload: \(reason)"
        case let .patchFailed(reason):
            return reason
        }
    }
}
