//
//  LegacyGaussianCookPath.swift
//  UntoldEngineTests
//
//  The whole-array cook as it stood before the streamed store (commit
//  1f9574fd): Data(contentsOf:) and the string-keyed parser, the importer
//  arrays through UntoldGSCooker.cook, makeUntoldGSSplats, and the array
//  writer with its [Data] payload list. Kept verbatim, test-side only, so
//  UntoldGSCookerEquivalenceTests can compare the bytes the two paths produce
//  for the same source in one process rather than new against new.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import simd
@testable import UntoldEngine

enum LegacyGaussianCookPath {
    // MARK: - Bake

    static func bake(
        sourceAsset: GaussianSplatAsset,
        emptySourceDescription: String,
        outputBaseURL: URL,
        lodFractions: [Float],
        cookOptions: UntoldGSCookOptions
    ) throws -> GaussianProgressiveBakeResult {
        guard !lodFractions.isEmpty else {
            throw UntoldGSError.sizeMismatch("lodFractions must contain at least one entry")
        }
        guard !sourceAsset.splats.isEmpty else {
            throw UntoldGSError.sizeMismatch(emptySourceDescription)
        }
        // Registration transform, opacity floor, crop and SH degree are applied once here so the
        // ranking, bounding box and every tier below see the cooked splats.
        let cooked = try UntoldGSCooker.cook(asset: sourceAsset, options: cookOptions)
        let asset = cooked.asset
        let assetBoundingBox = computeGaussianSplatBoundingBox(asset.splats)

        if lodFractions == [1.0] {
            let resultURL = outputBaseURL
            let allIndices = Array(asset.splats.indices)
            let tierExtent = meanSquaredSplatExtent(asset.splats, keeping: allIndices)
            let written = try LegacyGaussianCookPath.writeReporting(
                splats: makeUntoldGSSplats(asset: asset, keeping: allIndices),
                options: gaussianTierWriteOptions(shDegree: UInt8(clamping: asset.sphericalHarmonics?.degree ?? 0), boundingBox: assetBoundingBox, meanSquaredSplatExtent: tierExtent, cookOptions: cookOptions),
                to: resultURL
            )
            return GaussianProgressiveBakeResult(
                tiers: [GaussianLODTier(url: resultURL, meanSquaredSplatExtent: tierExtent, coarseReport: written.coarse)],
                boundingBoxMin: assetBoundingBox.min,
                boundingBoxMax: assetBoundingBox.max,
                cookReport: cooked.report
            )
        }

        let rankedIndices = try spatiallyInterleavedGaussianRanking(asset.splats)

        let baseWithoutExtension = outputBaseURL.deletingPathExtension()
        let baseName = baseWithoutExtension.lastPathComponent
        let baseDirectory = baseWithoutExtension.deletingLastPathComponent()

        var tiers: [GaussianLODTier] = []
        for (tierIndex, fraction) in lodFractions.enumerated() {
            let clampedFraction = min(max(fraction, 0), 1)
            let keepCount = max(1, Int((Float(asset.splats.count) * clampedFraction).rounded(.up)))
            let keptIndices = Array(rankedIndices.prefix(keepCount))
            let tierURL = baseDirectory
                .appendingPathComponent("\(baseName)_lod\(tierIndex)")
                .appendingPathExtension("untoldgs")
            let tierExtent = meanSquaredSplatExtent(asset.splats, keeping: keptIndices)
            let written = try LegacyGaussianCookPath.writeReporting(
                splats: makeUntoldGSSplats(asset: asset, keeping: keptIndices),
                options: gaussianTierWriteOptions(shDegree: UInt8(clamping: asset.sphericalHarmonics?.degree ?? 0), boundingBox: assetBoundingBox, meanSquaredSplatExtent: tierExtent, cookOptions: cookOptions),
                to: tierURL
            )
            tiers.append(GaussianLODTier(url: tierURL, meanSquaredSplatExtent: tierExtent, coarseReport: written.coarse))
        }
        return GaussianProgressiveBakeResult(
            tiers: tiers,
            boundingBoxMin: assetBoundingBox.min,
            boundingBoxMax: assetBoundingBox.max,
            cookReport: cooked.report
        )
    }

    // MARK: - Writer

    static func writeReporting(splats: [UntoldGSSplat], options: UntoldGSWriteOptions, serialCoarsening: Bool) throws -> (data: Data, report: UntoldGSWriteReport) {
        guard !splats.isEmpty else { throw UntoldGSError.invalidInput("no splats to write") }
        guard options.shDegree <= UntoldGSFormat.maxSHDegree else {
            throw UntoldGSError.unsupported("spherical-harmonics degree \(options.shDegree)")
        }
        guard options.log2ChunkSplats >= 1, options.log2ChunkSplats <= UntoldGSFormat.maxLog2ChunkSplats else {
            throw UntoldGSError.unsupported("log2ChunkSplats \(options.log2ChunkSplats)")
        }

        let shCount = UntoldGSFormat.shCoefficientCount(degree: options.shDegree)
        for (index, splat) in splats.enumerated() {
            guard splat.sphericalHarmonics.count == shCount else {
                throw UntoldGSError.invalidInput(
                    "splat \(index) carries \(splat.sphericalHarmonics.count) SH coefficients, expected \(shCount)"
                )
            }
            // One degenerate splat (a scale that overflowed through exp() on import, a NaN
            // colour) must fail the bake, not trap inside an integer conversion.
            guard splat.isFinite else {
                throw UntoldGSError.invalidInput("splat \(index) has non-finite data or a non-positive scale")
            }
        }

        let bounds = UntoldGSFormat.bounds(of: splats)
        let order = UntoldGSFormat.mortonOrder(splats, boundsMin: bounds.min, boundsMax: bounds.max)
        let splatsPerChunk = 1 << Int(options.log2ChunkSplats)
        let chunkRanges = stride(from: 0, to: order.count, by: splatsPerChunk).map { start in
            Array(order[start ..< min(start + splatsPerChunk, order.count)])
        }

        // The coarse levels: automatic above the chunk-count threshold (the template's ratios
        // clamped to the chunk size), or exactly what was asked for.
        let coarseOptions: UntoldGSCoarseLevelOptions? = try {
            if options.coarseLevelsAutomatic {
                let template = options.coarseLevels ?? .default
                try template.validate(log2ChunkSplats: UntoldGSFormat.maxLog2ChunkSplats)
                // Below the chunk-count threshold, or with chunks too small for any chunk to
                // have a level, no section at all.
                guard chunkRanges.count >= UntoldGSFormat.coarseLevelsAutomaticMinimumChunks, splatsPerChunk >= template.minimumChunkSplats else { return nil }
                let clamped = template.clamped(toLog2ChunkSplats: options.log2ChunkSplats)
                return clamped.levelCount > 0 ? clamped : nil
            }
            guard let requested = options.coarseLevels else { return nil }
            try requested.validate(log2ChunkSplats: options.log2ChunkSplats)
            return requested
        }()

        let headerSection = UntoldGSFormat.alignedToPage(UntoldGSFormat.headerSize)
        let chunkIndexOffset = headerSection
        let chunkIndexSection = UntoldGSFormat.alignedToPage(chunkRanges.count * UntoldGSFormat.chunkEntrySize)

        var entries: [UntoldGSChunkEntry] = []
        entries.reserveCapacity(chunkRanges.count)
        var payloads: [Data] = []
        payloads.reserveCapacity(chunkRanges.count)

        for indices in chunkRanges {
            var ordered = indices
            if options.sortByImportanceWithinChunk {
                ordered.sort { UntoldGSFormat.importance(splats[$0]) > UntoldGSFormat.importance(splats[$1]) }
            }
            let encoded = UntoldGSFormat.encodeChunk(ordered.map { splats[$0] }, shCount: shCount)
            entries.append(encoded.entry)
            payloads.append(encoded.payload)
        }

        // The merge seeds on the Morton order of each chunk (`chunkRanges`), not the importance
        // order the fine payload took; one chunk per iteration, results by chunk index. The
        // chunk's splats are gathered inside the work item, so one chunk's copy lives per thread
        // rather than a second copy of the whole tier for the pass.
        var coarseLevels: [UntoldGSCoarseLevels] = []
        if let coarseOptions {
            coarseLevels = try LegacyGaussianCookPath.coarsenChunks(splats, ranges: chunkRanges, options: coarseOptions, serial: serialCoarsening)
        }

        let nodes = try UntoldGSFormat.buildTree(entries: &entries, leafMaxChunks: max(1, options.leafMaxChunks))
        let nodeTreeOffset = chunkIndexOffset + chunkIndexSection
        let nodeTreeSection = UntoldGSFormat.alignedToPage(nodes.count * UntoldGSFormat.treeNodeSize)
        let payloadOffset = nodeTreeOffset + nodeTreeSection

        var cursor = payloadOffset
        for index in entries.indices {
            entries[index].payloadOffset = UInt64(cursor)
            cursor += Int(entries[index].payloadBytes)
        }
        var fileSize = cursor

        var flags: UInt32 = 0
        if options.shDegree > 0 {
            flags |= UntoldGSFlags.hasSphericalHarmonics
        }
        if options.antialiased {
            flags |= UntoldGSFlags.antialiased
        }
        if options.isEnvironment {
            flags |= UntoldGSFlags.environment
        }

        // The coarse section: the level-major index on the page after the last fine payload, the
        // records after it coarsest level first, each level in chunk order, 16-byte aligned.
        var coarseEntries: [UntoldGSChunkEntry] = []
        var coarsePayloads: [Data] = []
        var coarseIndexOffset = 0
        var coarsePayloadOffset = 0
        var coarseRecordCount = 0
        var coarseReport: UntoldGSCoarseLevelReport?
        if let coarseOptions {
            let levelCount = coarseOptions.levelCount
            coarseIndexOffset = UntoldGSFormat.alignedToPage(cursor)
            coarsePayloadOffset = coarseIndexOffset + UntoldGSFormat.alignedToPage(levelCount * entries.count * UntoldGSFormat.coarseIndexEntrySize)
            coarseEntries = [UntoldGSChunkEntry](repeating: UntoldGSChunkEntry.emptyCoarse(level: 0, chunk: 0, nodeId: 0), count: levelCount * entries.count)
            var recordsPerLevel = [Int](repeating: 0, count: levelCount)
            var chunksWithoutLevels = 0
            cursor = coarsePayloadOffset
            for level in stride(from: levelCount, through: 1, by: -1) {
                for chunk in entries.indices {
                    let merged = coarseLevels[chunk].level(level)
                    let slot = (level - 1) * entries.count + chunk
                    if level == 1, merged.isEmpty {
                        chunksWithoutLevels += 1
                    }
                    guard !merged.isEmpty else {
                        coarseEntries[slot] = .emptyCoarse(level: UInt16(level), chunk: UInt32(chunk), nodeId: entries[chunk].nodeId)
                        continue
                    }
                    let encoded = UntoldGSFormat.encodeChunk(UntoldGSFormat.orderedByImportance(merged), shCount: 0, padToPage: false)
                    var entry = encoded.entry
                    entry.payloadOffset = UInt64(cursor)
                    entry.lodLevel = UInt16(level)
                    entry.nodeId = entries[chunk].nodeId
                    entry.reserved0 = UInt32(chunk)
                    coarseEntries[slot] = entry
                    coarsePayloads.append(encoded.payload)
                    cursor += encoded.payload.count
                    recordsPerLevel[level - 1] += merged.count
                    coarseRecordCount += merged.count
                }
            }
            fileSize = UntoldGSFormat.alignedToPage(cursor)
            flags |= UntoldGSFlags.hasCoarseLevels
            coarseReport = UntoldGSCoarseLevelReport(
                levelCount: levelCount,
                ratioLog2: Array(coarseOptions.ratioLog2.prefix(levelCount)),
                recordsPerLevel: recordsPerLevel,
                bytes: fileSize - coarseIndexOffset,
                chunksWithoutLevels: chunksWithoutLevels
            )
        }

        // Only scanned when the caller did not supply a box (the bake always does).
        let boundingBox = (options.boundingBoxMin == nil || options.boundingBoxMax == nil)
            ? UntoldGSFormat.defaultBoundingBox(of: splats)
            : (min: options.boundingBoxMin!, max: options.boundingBoxMax!)
        let header = UntoldGSHeaderV3(
            flags: flags,
            shDegree: options.shDegree,
            coordinateSystem: options.coordinateSystem,
            colorSpace: options.colorSpace,
            log2ChunkSplats: options.log2ChunkSplats,
            splatCount: UInt32(splats.count),
            chunkCount: UInt32(entries.count),
            nodeCount: UInt32(nodes.count),
            lodLevels: 1,
            boundsMin: bounds.min,
            boundsMax: bounds.max,
            boundingBoxMin: options.boundingBoxMin ?? boundingBox.min,
            boundingBoxMax: options.boundingBoxMax ?? boundingBox.max,
            meanSquaredSplatExtent: options.meanSquaredSplatExtent,
            captureExposureEV: options.captureExposureEV,
            captureWhiteBalance: options.captureWhiteBalance,
            splatToMesh: options.splatToMesh,
            chunkIndexOffset: UInt64(chunkIndexOffset),
            nodeTreeOffset: UInt64(nodeTreeOffset),
            paletteOffset: 0,
            payloadOffset: UInt64(payloadOffset),
            fileSize: UInt64(fileSize),
            coarseIndexOffset: UInt64(coarseIndexOffset),
            coarsePayloadOffset: UInt64(coarsePayloadOffset),
            coarseRecordCount: UInt32(coarseRecordCount),
            coarseLevelCount: UInt8(coarseOptions?.levelCount ?? 0),
            coarseRatioLog2: coarseOptions.map { Array($0.ratioLog2.prefix($0.levelCount)) } ?? [0, 0]
        )

        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        writer.align(to: UntoldGSFormat.pageAlignment)
        for entry in entries {
            entry.encode(to: writer)
        }
        writer.align(to: UntoldGSFormat.pageAlignment)
        for node in nodes {
            node.encode(to: writer)
        }
        writer.align(to: UntoldGSFormat.pageAlignment)
        precondition(writer.count == payloadOffset, "section layout mismatch")
        for payload in payloads {
            writer.writeData(payload)
            writer.align(to: UntoldGSFormat.pageAlignment)
        }
        if coarseOptions != nil {
            precondition(writer.count == coarseIndexOffset, "coarse index layout mismatch")
            for entry in coarseEntries {
                entry.encode(to: writer)
            }
            writer.align(to: UntoldGSFormat.pageAlignment)
            precondition(writer.count == coarsePayloadOffset, "coarse payload layout mismatch")
            for payload in coarsePayloads {
                writer.writeData(payload)
            }
            writer.align(to: UntoldGSFormat.pageAlignment)
        }
        precondition(writer.count == fileSize, "payload layout mismatch")
        return (writer.data, UntoldGSWriteReport(chunkCount: entries.count, coarse: coarseReport))
    }

    /// `write(splats:options:to:)` as it stood: the whole image, then `Data.write(.atomic)`.
    static func writeReporting(splats: [UntoldGSSplat], options: UntoldGSWriteOptions = .init(), to url: URL) throws -> UntoldGSWriteReport {
        let (data, report) = try writeReporting(splats: splats, options: options, serialCoarsening: false)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return report
    }

    // MARK: - Coarse levels

    /// Coarsens every chunk — `ranges[c]` the indices into `splats` of chunk `c`, in Morton
    /// order — in parallel unless `serial`; the result of chunk `c` lands at index `c` whatever
    /// the scheduling, and each chunk's arithmetic is sequential in a fixed order, so the bytes
    /// never depend on the thread count. Each work item gathers its own chunk's splats, so the
    /// memory in flight is one chunk per thread, not a copy of the tier.
    static func coarsenChunks(_ splats: [UntoldGSSplat], ranges: [[Int]], options: UntoldGSCoarseLevelOptions, serial: Bool) throws -> [UntoldGSCoarseLevels] {
        let results = CoarsenedChunks(count: ranges.count)
        let work: @Sendable (Int) -> Void = { chunk in
            do {
                let gathered = ranges[chunk].map { splats[$0] }
                try results.store(UntoldGSCoarsener.coarsen(gathered, options: options), at: chunk)
            } catch let error as UntoldGSError {
                results.fail(error, at: chunk)
            } catch {
                results.fail(.invalidInput("\(error)"), at: chunk)
            }
        }
        if serial {
            for chunk in ranges.indices {
                work(chunk)
            }
        } else {
            DispatchQueue.concurrentPerform(iterations: ranges.count, execute: work)
        }
        return try results.take()
    }

    /// The coarsener's per-chunk results, filled from `concurrentPerform` under one lock (one
    /// store per chunk, so the lock is never contended for long).
    private final class CoarsenedChunks: @unchecked Sendable {
        private let lock = NSLock()
        private var levels: [UntoldGSCoarseLevels]
        private var failures: [UntoldGSError?]

        init(count: Int) {
            levels = [UntoldGSCoarseLevels](repeating: .none, count: count)
            failures = [UntoldGSError?](repeating: nil, count: count)
        }

        func store(_ result: UntoldGSCoarseLevels, at chunk: Int) {
            lock.withLock { levels[chunk] = result }
        }

        func fail(_ error: UntoldGSError, at chunk: Int) {
            lock.withLock { failures[chunk] = error }
        }

        /// The levels by chunk index, or the first chunk's failure.
        func take() throws -> [UntoldGSCoarseLevels] {
            try lock.withLock {
                if let failure = failures.compactMap({ $0 }).first {
                    throw failure
                }
                return levels
            }
        }
    }

    // MARK: - Reader

    static func readGaussianAsset(from url: URL) throws -> GaussianSplatAsset {
        let data = try Data(contentsOf: url)
        let (header, bodyOffset) = try PLYReader.parseHeader(from: data)

        // Find the vertex element (Gaussian splats are typically stored as vertices)
        guard let vertexElement = header.elements.first(where: { $0.name == "vertex" }) else {
            throw PLYError.missingElement("vertex")
        }

        let shSchema = try PLYReader.sphericalHarmonicSchema(for: vertexElement.properties)

        // Parse the body based on format
        let parsed: ([GaussianSplat], [Float])
        switch header.format {
        case .ascii:
            parsed = try parseASCIIGaussians(data: data, bodyOffset: bodyOffset, element: vertexElement, shSchema: shSchema)
        case .binaryLittleEndian:
            parsed = try parseBinaryGaussians(data: data, bodyOffset: bodyOffset, element: vertexElement, bigEndian: false, shSchema: shSchema)
        case .binaryBigEndian:
            parsed = try parseBinaryGaussians(data: data, bodyOffset: bodyOffset, element: vertexElement, bigEndian: true, shSchema: shSchema)
        }

        if let shSchema,
           parsed.1.count != vertexElement.count * shSchema.coefficientsPerSplat
        {
            throw PLYError.invalidData("Spherical-harmonic coefficient data is incomplete")
        }

        let (filteredSplats, filteredCoefficients) = filterNegligibleOpacityGaussianSplats(
            splats: parsed.0,
            shCoefficients: parsed.1,
            coefficientsPerSplat: shSchema?.coefficientsPerSplat ?? 0,
            sourceTag: "PLY"
        )

        let sphericalHarmonics = shSchema.map {
            GaussianSphericalHarmonics(
                degree: $0.degree,
                coefficientsPerChannel: $0.coefficientsPerChannel,
                coefficients: filteredCoefficients
            )
        }
        return GaussianSplatAsset(splats: filteredSplats, sphericalHarmonics: sphericalHarmonics)
    }

    // MARK: - ASCII Parsing

    private static func parseASCIIGaussians(
        data: Data,
        bodyOffset: Int,
        element: PLYElement,
        shSchema: PLYReader.SphericalHarmonicSchema?
    ) throws -> ([GaussianSplat], [Float]) {
        // Get the body string
        let bodyData = data.suffix(from: bodyOffset)
        guard let bodyString = String(data: bodyData, encoding: .utf8) else {
            throw PLYError.invalidFormat("Cannot decode body as UTF-8")
        }

        let lines = bodyString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var splats: [GaussianSplat] = []
        splats.reserveCapacity(element.count)
        var shCoefficients: [Float] = []
        if let shSchema {
            shCoefficients.reserveCapacity(element.count * shSchema.coefficientsPerSplat)
        }

        // Create property index map
        let propertyMap = createPropertyIndexMap(properties: element.properties)

        for line in lines.prefix(element.count) {
            let values = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            if values.isEmpty { continue }

            let splat = try parseGaussianFromValues(
                values: values,
                propertyMap: propertyMap,
                shSchema: shSchema,
                shCoefficients: &shCoefficients
            )
            splats.append(splat)
        }

        guard splats.count == element.count else {
            throw PLYError.invalidData("Expected \(element.count) Gaussian vertices, found \(splats.count)")
        }
        return (splats, shCoefficients)
    }

    // MARK: - Binary Parsing

    private static func parseBinaryGaussians(
        data: Data,
        bodyOffset: Int,
        element: PLYElement,
        bigEndian: Bool,
        shSchema: PLYReader.SphericalHarmonicSchema?
    ) throws -> ([GaussianSplat], [Float]) {
        var splats: [GaussianSplat] = []
        splats.reserveCapacity(element.count)
        var shCoefficients: [Float] = []
        if let shSchema {
            shCoefficients.reserveCapacity(element.count * shSchema.coefficientsPerSplat)
        }

        // Calculate stride for each vertex
        let stride = calculateStride(properties: element.properties)
        let propertyMap = createPropertyIndexMap(properties: element.properties)
        let propertyOffsets = calculatePropertyOffsets(properties: element.properties)

        var offset = bodyOffset

        for _ in 0 ..< element.count {
            guard offset + stride <= data.count else {
                throw PLYError.invalidFormat("Unexpected end of file")
            }

            let vertexData = data.subdata(in: offset ..< (offset + stride))
            let splat = try parseGaussianFromBinary(
                data: vertexData,
                properties: element.properties,
                propertyMap: propertyMap,
                propertyOffsets: propertyOffsets,
                bigEndian: bigEndian,
                shSchema: shSchema,
                shCoefficients: &shCoefficients
            )
            splats.append(splat)

            offset += stride
        }

        return (splats, shCoefficients)
    }

    // MARK: - Gaussian Parsing Helpers

    private static func createPropertyIndexMap(properties: [PLYProperty]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (index, property) in properties.enumerated() {
            map[property.name] = index
        }
        return map
    }

    private static func parseGaussianFromValues(
        values: [String],
        propertyMap: [String: Int],
        shSchema: PLYReader.SphericalHarmonicSchema?,
        shCoefficients: inout [Float]
    ) throws -> GaussianSplat {
        // Extract position
        let x = try getFloat(values: values, propertyMap: propertyMap, key: "x")
        let y = try getFloat(values: values, propertyMap: propertyMap, key: "y")
        let z = try getFloat(values: values, propertyMap: propertyMap, key: "z")

        // Extract scale (often stored as log scale in PLY)
        let scale0 = try getFloat(values: values, propertyMap: propertyMap, key: "scale_0", default: 0.0)
        let scale1 = try getFloat(values: values, propertyMap: propertyMap, key: "scale_1", default: 0.0)
        let scale2 = try getFloat(values: values, propertyMap: propertyMap, key: "scale_2", default: 0.0)

        // Convert from log scale to linear scale
        let scaleX = exp(scale0)
        let scaleY = exp(scale1)
        let scaleZ = exp(scale2)

        // Extract color (from spherical harmonics DC component or direct RGB)
        var r: Float, g: Float, b: Float
        if let shSchema {
            // Color from spherical harmonics
            let dcR = try getFloat(values: values, propertyMap: propertyMap, key: "f_dc_0")
            let dcG = try getFloat(values: values, propertyMap: propertyMap, key: "f_dc_1")
            let dcB = try getFloat(values: values, propertyMap: propertyMap, key: "f_dc_2")
            r = dcR
            g = dcG
            b = dcB

            // Convert from SH to RGB (DC component of SH corresponds to RGB / C0 where C0 = 0.28209479177387814)
            let C0: Float = 0.28209479177387814
            r = (r * C0 + 0.5)
            g = (g * C0 + 0.5)
            b = (b * C0 + 0.5)

            let dc = (dcR, dcG, dcB)
            let restPerChannel = shSchema.coefficientsPerChannel - 1
            for channel in 0 ..< 3 {
                shCoefficients.append(channel == 0 ? dc.0 : (channel == 1 ? dc.1 : dc.2))
                let start = channel * restPerChannel
                for index in start ..< start + restPerChannel {
                    try shCoefficients.append(
                        getFloat(
                            values: values,
                            propertyMap: propertyMap,
                            key: shSchema.restPropertyNames[index]
                        )
                    )
                }
            }
        } else {
            // Direct RGB
            r = try getFloat(values: values, propertyMap: propertyMap, key: "red", default: 1.0) / 255.0
            g = try getFloat(values: values, propertyMap: propertyMap, key: "green", default: 1.0) / 255.0
            b = try getFloat(values: values, propertyMap: propertyMap, key: "blue", default: 1.0) / 255.0
        }

        // Extract opacity (often stored as logit)
        let opacity = try getFloat(values: values, propertyMap: propertyMap, key: "opacity", default: 0.0)
        let alpha = 1.0 / (1.0 + exp(-opacity)) // Sigmoid to convert from logit to [0,1]

        // Extract rotation quaternion
        let rot0 = try getFloat(values: values, propertyMap: propertyMap, key: "rot_0", default: 1.0)
        let rot1 = try getFloat(values: values, propertyMap: propertyMap, key: "rot_1", default: 0.0)
        let rot2 = try getFloat(values: values, propertyMap: propertyMap, key: "rot_2", default: 0.0)
        let rot3 = try getFloat(values: values, propertyMap: propertyMap, key: "rot_3", default: 0.0)

        // Normalize quaternion
        let quat = simd_normalize(simd_float4(rot0, rot1, rot2, rot3))

        return GaussianSplat(
            center: simd_float4(x, y, z, 1.0),
            scale: simd_float4(scaleX, scaleY, scaleZ, 1.0),
            color: simd_float4(r, g, b, alpha),
            quat: quat,
            opacity: alpha
        )
    }

    private static func getFloat(values: [String], propertyMap: [String: Int], key: String, default defaultValue: Float? = nil) throws -> Float {
        guard let index = propertyMap[key] else {
            if let defaultValue {
                return defaultValue
            }
            throw PLYError.missingProperty(key)
        }
        guard index < values.count, let value = Float(values[index]) else {
            throw PLYError.invalidData("Cannot parse float for property '\(key)'")
        }
        return value
    }

    // MARK: - Binary Helpers

    private static func calculateStride(properties: [PLYProperty]) -> Int {
        var stride = 0
        for property in properties {
            if property.isList {
                // Lists are variable length, cannot be handled in fixed stride
                // For Gaussian splats, we typically don't have lists
                continue
            }
            stride += PLYReader.sizeOfType(property.type)
        }
        return stride
    }

    private static func calculatePropertyOffsets(properties: [PLYProperty]) -> [Int] {
        var offsets: [Int] = []
        var currentOffset = 0
        for property in properties {
            offsets.append(currentOffset)
            if !property.isList {
                currentOffset += PLYReader.sizeOfType(property.type)
            }
        }
        return offsets
    }

    private static func parseGaussianFromBinary(
        data: Data,
        properties: [PLYProperty],
        propertyMap: [String: Int],
        propertyOffsets: [Int],
        bigEndian: Bool,
        shSchema: PLYReader.SphericalHarmonicSchema?,
        shCoefficients: inout [Float]
    ) throws -> GaussianSplat {
        func readFloat(propertyName: String, default defaultValue: Float? = nil) throws -> Float {
            guard let index = propertyMap[propertyName] else {
                if let defaultValue {
                    return defaultValue
                }
                throw PLYError.missingProperty(propertyName)
            }

            let offset = propertyOffsets[index]
            let property = properties[index]
            let size = PLYReader.sizeOfType(property.type)

            guard offset + size <= data.count else {
                throw PLYError.invalidData("Buffer overflow reading '\(propertyName)'")
            }

            return try convertToFloat(
                data: data,
                offset: offset,
                type: property.type,
                bigEndian: bigEndian
            )
        }

        // Extract all properties
        let x = try readFloat(propertyName: "x")
        let y = try readFloat(propertyName: "y")
        let z = try readFloat(propertyName: "z")

        let scale0 = try readFloat(propertyName: "scale_0", default: 0.0)
        let scale1 = try readFloat(propertyName: "scale_1", default: 0.0)
        let scale2 = try readFloat(propertyName: "scale_2", default: 0.0)

        let scaleX = exp(scale0)
        let scaleY = exp(scale1)
        let scaleZ = exp(scale2)

        var r: Float, g: Float, b: Float
        if let shSchema {
            let dcR = try readFloat(propertyName: "f_dc_0")
            let dcG = try readFloat(propertyName: "f_dc_1")
            let dcB = try readFloat(propertyName: "f_dc_2")
            r = dcR
            g = dcG
            b = dcB

            let C0: Float = 0.28209479177387814
            r = (r * C0 + 0.5)
            g = (g * C0 + 0.5)
            b = (b * C0 + 0.5)

            let dc = (dcR, dcG, dcB)
            let restPerChannel = shSchema.coefficientsPerChannel - 1
            for channel in 0 ..< 3 {
                shCoefficients.append(channel == 0 ? dc.0 : (channel == 1 ? dc.1 : dc.2))
                let start = channel * restPerChannel
                for index in start ..< start + restPerChannel {
                    try shCoefficients.append(
                        readFloat(propertyName: shSchema.restPropertyNames[index])
                    )
                }
            }
        } else {
            r = try readFloat(propertyName: "red", default: 1.0) / 255.0
            g = try readFloat(propertyName: "green", default: 1.0) / 255.0
            b = try readFloat(propertyName: "blue", default: 1.0) / 255.0
        }

        let opacity = try readFloat(propertyName: "opacity", default: 0.0)
        let alpha = 1.0 / (1.0 + exp(-opacity))

        let rot0 = try readFloat(propertyName: "rot_0", default: 1.0)
        let rot1 = try readFloat(propertyName: "rot_1", default: 0.0)
        let rot2 = try readFloat(propertyName: "rot_2", default: 0.0)
        let rot3 = try readFloat(propertyName: "rot_3", default: 0.0)

        let quat = simd_normalize(simd_float4(rot0, rot1, rot2, rot3))

        return GaussianSplat(
            center: simd_float4(x, y, z, 1.0),
            scale: simd_float4(scaleX, scaleY, scaleZ, 1.0),
            color: simd_float4(r, g, b, alpha),
            quat: quat,
            opacity: alpha
        )
    }

    private static func convertToFloat(data: Data, offset: Int, type: String, bigEndian: Bool) throws -> Float {
        try data.withUnsafeBytes { bytes in
            switch type {
            case "float", "float32":
                var bits = bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                if bigEndian { bits = UInt32(bigEndian: bits) }
                return Float(bitPattern: bits)

            case "double", "float64":
                var bits = bytes.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
                if bigEndian { bits = UInt64(bigEndian: bits) }
                return Float(Double(bitPattern: bits))

            case "uchar", "uint8":
                return Float(bytes[offset])

            case "char", "int8":
                return Float(Int8(bitPattern: bytes[offset]))

            case "ushort", "uint16":
                var value = bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
                if bigEndian { value = UInt16(bigEndian: value) }
                return Float(value)

            case "short", "int16":
                var value = bytes.loadUnaligned(fromByteOffset: offset, as: Int16.self)
                if bigEndian { value = Int16(bigEndian: value) }
                return Float(value)

            case "uint", "uint32":
                var value = bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                if bigEndian { value = UInt32(bigEndian: value) }
                return Float(value)

            case "int", "int32":
                var value = bytes.loadUnaligned(fromByteOffset: offset, as: Int32.self)
                if bigEndian { value = Int32(bigEndian: value) }
                return Float(value)

            default:
                throw PLYError.unsupportedType(type)
            }
        }
    }
}
