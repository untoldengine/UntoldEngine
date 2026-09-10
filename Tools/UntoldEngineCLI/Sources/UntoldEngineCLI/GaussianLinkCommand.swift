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
import simd
import UntoldEngine

struct GaussianLinkCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gaussian-link",
        abstract: "Link an entity of a .untold asset to a cooked .untoldgs splat payload",
        discussion: """
        Writes, removes or lists the gaussianAsset records of a .untold file
        (chunk 25, UntoldGaussianAssetRecordV1) through UntoldAssetPatcher. Every
        other chunk of the file is copied byte for byte; the string table only
        grows.

        The payload path is stored relative to the directory of the file that is
        written (the input with --in-place, the --output file otherwise) when the
        payload sits inside or beside it, else as the bare file name with a
        warning — the runtime resolves it next to the .untold file it loads. The
        payload must be a version 3 .untoldgs; its splat count fills the record's
        single LOD level. The link is set on the entity table's entityId; a
        meshTwin link on an entity without a mesh has nothing to swap from, so the
        command warns and lists the entities that carry meshes.

        The alignment options place the splat inside the entity without a re-cook
        (translation in metres, yaw about +Y in degrees, uniform scale; the runtime
        draws the splat with T·R·S composed onto the entity transform). Options
        left out keep what the entity's existing link already stores;
        --clear-alignment removes it.

        Examples:
          untoldengine gaussian-link --untold Chair/chair.untold --entity 0 \\
            --payload Chair/chair.untoldgs --swap-distance 8 --in-place
          untoldengine gaussian-link --untold Chair/chair.untold --entity 0 \\
            --payload Chair/chair.untoldgs --align-translate 0,0.02,-0.1 \\
            --align-yaw-degrees 90 --align-scale 1.02 --in-place
          untoldengine gaussian-link --untold Chair/chair.untold --entity 0 \\
            --remove --output Chair/chair_plain.untold
          untoldengine gaussian-link --untold Chair/chair.untold --list
        """
    )

    @Option(name: .long, help: "The .untold asset to patch or list")
    var untold: String

    @Option(name: .long, help: "Entity id (the entity table's entityId) the link is set on or removed from")
    var entity: UInt32?

    @Option(name: .long, help: "The cooked .untoldgs payload to link")
    var payload: String?

    // `.unconditional`: the next token is the value even when it starts with a minus sign, so
    // `--exposure-offset -0.5` parses without the `--option=value` form.
    @Option(name: .customLong("swap-distance"), parsing: .unconditional, help: "Camera distance in metres at which the swap arms (0 = always)")
    var swapDistance: Float = 0

    @Option(name: .customLong("occluder-shrink"), parsing: .unconditional, help: "Metres the mesh twin's depth-only occluder shell is shrunk along its normals")
    var occluderShrink: Float = 0.02

    @Option(name: .customLong("exposure-offset"), parsing: .unconditional, help: "Exposure offset in EV on top of the payload's capture exposure (negative darkens)")
    var exposureOffset: Float = 0

    @Option(name: .customLong("align-translate"), parsing: .unconditional, help: "Offset of the splat in the entity's local space, metres, as x,y,z")
    var alignTranslate: String?

    @Option(name: .customLong("align-yaw-degrees"), parsing: .unconditional, help: "Rotation of the splat about the entity's +Y axis, degrees")
    var alignYawDegrees: Float?

    @Option(name: .customLong("align-scale"), parsing: .unconditional, help: "Uniform scale of the splat, greater than zero")
    var alignScale: Float?

    @Flag(name: .customLong("clear-alignment"), help: "Drop the alignment the entity's existing link stores")
    var clearAlignment = false

    @Flag(name: .customLong("in-place"), help: "Overwrite the .untold file")
    var inPlace = false

    @Option(name: .long, help: "Write the patched file here instead of overwriting the input")
    var output: String?

    @Flag(name: .long, help: "Remove the entity's link instead of setting one")
    var remove = false

    @Flag(name: .long, help: "Print the links the file carries and exit")
    var list = false

    private var hasAlignmentOption: Bool {
        alignTranslate != nil || alignYawDegrees != nil || alignScale != nil
    }

    func validate() throws {
        if list {
            guard !remove, payload == nil, !inPlace, output == nil, !hasAlignmentOption, !clearAlignment else {
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
            guard !hasAlignmentOption, !clearAlignment else {
                throw ValidationError("--remove takes no alignment option.")
            }
        } else {
            guard payload != nil else {
                throw ValidationError("Provide --payload, --remove or --list.")
            }
            guard !(clearAlignment && hasAlignmentOption) else {
                throw ValidationError("--clear-alignment takes no --align-* option.")
            }
            if let alignTranslate {
                _ = try Self.parseTranslation(alignTranslate)
            }
            if let alignScale, !(alignScale.isFinite && alignScale > 0) {
                throw ValidationError("--align-scale must be greater than zero.")
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
        // The runtime resolves the stored path next to the file it loads, which is the
        // destination — not the input — when --output points elsewhere.
        let destination = output.map { resolvePath($0).standardizedFileURL } ?? untoldURL
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
            let stored = Self.storedPayloadPath(payloadURL: payloadURL, untoldURL: destination)
            if !stored.isRelative {
                printWarning("\(payloadURL.path) is not inside \(destination.deletingLastPathComponent().path); storing the file name \(stored.path) — keep the payload next to the .untold file that is written")
            }
            var link = try Self.makeLink(
                payloadURL: payloadURL,
                storedPath: stored.path,
                swapDistance: swapDistance,
                occluderShrink: occluderShrink,
                exposureOffset: exposureOffset
            )
            link.alignment = try Self.mergedAlignment(
                existing: Self.existingAlignment(entity: entity, in: fileData),
                translate: alignTranslate.map { try Self.parseTranslation($0) },
                yawDegrees: alignYawDegrees,
                scale: alignScale,
                clear: clearAlignment
            )
            if let warning = try Self.meshlessEntityWarning(entity: entity, link: link, in: fileData) {
                printWarning(warning)
            }
            patched = try Self.setting(link, entity: entity, in: fileData)
            let alignment = link.alignment.map { ", \(Self.describe($0))" } ?? ""
            printInfo("Linked entity \(entity) to \(stored.path) (\(link.lodSplatCounts.first ?? 0) splats, swap at \(swapDistance) m, shrink \(occluderShrink) m, \(exposureOffset) EV\(alignment))")
        }

        try patched.write(to: destination, options: .atomic)
        printSuccess("Wrote \(destination.path)")
    }

    // MARK: - Logic (kept free of ArgumentParser so tests can call it)

    /// The path written into the record: relative to the directory of `untoldURL` — the file
    /// the record will be loaded from, so the `--output` destination when there is one — when
    /// the payload is inside or beside it, else the bare file name. The paths are compared as
    /// given first, so a payload reached through a symlinked directory inside the asset folder
    /// keeps that working relative path; only when that fails are symlinks resolved on both
    /// sides, for an asset folder reached through a link.
    static func storedPayloadPath(payloadURL: URL, untoldURL: URL) -> (path: String, isRelative: Bool) {
        let directory = untoldURL.deletingLastPathComponent().standardizedFileURL
        let payload = payloadURL.standardizedFileURL
        if let relative = relativePath(of: payload, inside: directory) {
            return (relative, true)
        }
        if let relative = relativePath(of: payload.resolvingSymlinksInPath(), inside: directory.resolvingSymlinksInPath()) {
            return (relative, true)
        }
        return (payloadURL.lastPathComponent, false)
    }

    private static func relativePath(of file: URL, inside directory: URL) -> String? {
        let directory = directory.pathComponents
        let file = file.pathComponents
        guard file.count > directory.count, Array(file.prefix(directory.count)) == directory else {
            return nil
        }
        return file.dropFirst(directory.count).joined(separator: "/")
    }

    /// A warning when `link` is a meshTwin and `entity` carries no mesh record — the root of a
    /// multi-node asset, say — naming the entities that do, so the link can be moved to one of
    /// them. Nil when the entity has a mesh, the link is not a meshTwin, or the entity is
    /// unknown (the patcher reports that one).
    static func meshlessEntityWarning(entity: UInt32, link: UntoldAssetPatcher.GaussianAssetLink, in fileData: Data) throws -> String? {
        guard link.flags & UntoldGaussianAssetFlags.meshTwin != 0 else { return nil }
        let decoded: UntoldDecodedAsset
        do {
            decoded = try UntoldReader().readAsset(from: fileData)
        } catch {
            throw GaussianLinkError.patchFailed(UntoldAssetPatcher.Error.corruptFile(String(describing: error)).description)
        }
        guard let record = decoded.entities.first(where: { $0.entityId == entity }), record.meshRecordCount == 0 else {
            return nil
        }
        let withMeshes = decoded.entities.filter { $0.meshRecordCount > 0 }.map { record in
            let name = try? decoded.string(at: record.nameOffset)
            return name.map { "\(record.entityId) (\($0))" } ?? "\(record.entityId)"
        }
        let candidates = withMeshes.isEmpty ? "no entity of this file carries a mesh" : "entities with meshes: \(withMeshes.joined(separator: ", "))"
        return "entity \(entity) has no mesh to swap from; the meshTwin link will load but GaussianTwinSystem has nothing to hide — \(candidates)"
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

    /// `x,y,z` as three finite floats (spaces around the commas allowed).
    static func parseTranslation(_ text: String) throws -> SIMD3<Float> {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 else {
            throw ValidationError("--align-translate takes x,y,z; got '\(text)'.")
        }
        let values = parts.compactMap(Float.init)
        guard values.count == 3, values.allSatisfy(\.isFinite) else {
            throw ValidationError("--align-translate takes three finite numbers; got '\(text)'.")
        }
        return SIMD3<Float>(values[0], values[1], values[2])
    }

    /// The alignment the entity's link in `fileData` stores, nil without a link or alignment.
    static func existingAlignment(entity: UInt32, in fileData: Data) throws -> GaussianSplatAlignment? {
        do {
            return try UntoldAssetPatcher.gaussianAssets(in: fileData)[entity]?.alignment
        } catch let error as UntoldAssetPatcher.Error {
            throw GaussianLinkError.patchFailed(error.description)
        }
    }

    /// What the new link stores: nothing with `clear`; `existing` untouched when no field is
    /// given; otherwise the given fields over `existing` (identity when there is none).
    static func mergedAlignment(
        existing: GaussianSplatAlignment?,
        translate: SIMD3<Float>?,
        yawDegrees: Float?,
        scale: Float?,
        clear: Bool
    ) -> GaussianSplatAlignment? {
        if clear { return nil }
        guard translate != nil || yawDegrees != nil || scale != nil else { return existing }
        var alignment = existing ?? .identity
        if let translate { alignment.translation = translate }
        if let yawDegrees { alignment.yawDegrees = yawDegrees }
        if let scale { alignment.scale = scale }
        return alignment
    }

    /// `align (x, y, z) m, yaw d°, scale s` for the listing and the info line.
    static func describe(_ alignment: GaussianSplatAlignment) -> String {
        let t = alignment.translation
        return "align (\(t.x), \(t.y), \(t.z)) m, yaw \(alignment.yawDegrees)°, scale \(alignment.scale)"
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
            let alignment = link.alignment.map { ", \(describe($0))" } ?? ""
            return "entity \(entity): \(link.payloadPath) [\(flags.joined(separator: ","))] \(levels), swap \(link.swapDistanceMeters) m, shrink \(link.occluderShrinkMeters) m, \(link.exposureOffsetEV) EV\(alignment)"
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
