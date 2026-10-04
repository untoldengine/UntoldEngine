//
//  UntoldPackLODCooker.swift
//  UntoldEngineMeshCook
//
//  Builds the LOD chains of the models of a cooked `.untoldpack` and records them in
//  its manifest.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// What `UntoldMeshLODCooker.cookChains(forPackAt:)` did.
public struct UntoldPackLODReport: Sendable, Equatable {
    public struct Failure: Sendable, Equatable {
        /// The model's path as the manifest writes it.
        public var path: String
        public var reason: String
    }

    /// Distinct `.untold` files the manifest places.
    public var modelCount = 0
    /// Models that got at least one level.
    public var chainCount = 0
    public var levelCount = 0
    /// Triangles of the models that got a chain.
    public var chainedTriangleCount = 0
    /// Triangles of the coarsest level of each chain.
    public var coarsestTriangleCount = 0
    /// Bytes of the level files written.
    public var levelBytes: Int64 = 0
    /// Models left without a chain because a file that is not one of their levels has a
    /// level's name (`UntoldMeshLODChain.SkipReason.levelNameTaken`), by manifest path.
    public var blockedPaths: [String] = []
    /// Models that could not be read or written; they keep working without a chain.
    public var failures: [Failure] = []
}

public extension UntoldMeshLODCooker {
    /// The manifest key the chains are recorded under: for each model path, its levels
    /// from the finest, each with the `path` of its file (relative to the manifest, like
    /// the model's), its `screenSize`, its `triangles` and the simplifier's `error`.
    static let packManifestKey = "lodChains"

    /// Builds a LOD chain for every distinct model of the pack at `packURL` (see
    /// `cookChain(forModelAt:options:)`) and rewrites the manifest with them. A model
    /// placed many times is simplified once. The rest of the manifest is kept as it is.
    ///
    /// `progress` is called after each model with the number done and the total; it can
    /// be called from any thread, one call at a time.
    @discardableResult
    static func cookChains(
        forPackAt packURL: URL,
        options: UntoldMeshLODOptions = UntoldMeshLODOptions(),
        progress: (@Sendable (_ done: Int, _ total: Int) -> Void)? = nil
    ) throws -> UntoldPackLODReport {
        try options.validate()

        var manifest: [String: Any]
        do {
            let data = try Data(contentsOf: packURL)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw UntoldMeshLODError.unreadableManifest(path: packURL.path, reason: "the manifest is not a JSON object")
            }
            manifest = object
        } catch let error as UntoldMeshLODError {
            throw error
        } catch {
            throw UntoldMeshLODError.unreadableManifest(path: packURL.path, reason: error.localizedDescription)
        }
        guard let models = manifest["models"] as? [[String: Any]] else {
            throw UntoldMeshLODError.unreadableManifest(path: packURL.path, reason: "the manifest has no models")
        }

        var seen = Set<String>()
        let paths = models.compactMap { $0["path"] as? String }.filter { seen.insert($0).inserted }
        let packDirectory = packURL.deletingLastPathComponent()

        let results = ChainResults(count: paths.count)
        DispatchQueue.concurrentPerform(iterations: paths.count) { index in
            let modelURL = packDirectory.appendingPathComponent(paths[index])
            let result = Result { try cookChain(forModelAt: modelURL, options: options) }
            let done = results.set(result, at: index)
            if let progress {
                results.report { progress(done, paths.count) }
            }
        }

        var report = UntoldPackLODReport()
        report.modelCount = paths.count
        var chains: [String: Any] = [:]
        for (path, result) in zip(paths, results.all()) {
            switch result {
            case let .success(chain):
                if chain.skipped == .levelNameTaken {
                    report.blockedPaths.append(path)
                }
                guard let coarsest = chain.levels.last else { continue }
                report.chainCount += 1
                report.levelCount += chain.levels.count
                report.chainedTriangleCount += chain.triangleCount
                report.coarsestTriangleCount += coarsest.triangleCount
                let directory = (path as NSString).deletingLastPathComponent
                chains[path] = chain.levels.map { level -> [String: Any] in
                    report.levelBytes += fileSize(level.url)
                    return [
                        "path": (directory as NSString).appendingPathComponent(level.url.lastPathComponent),
                        "triangles": level.triangleCount,
                        "screenSize": rounded(level.screenSize),
                        "error": rounded(level.error),
                    ]
                }
            case let .failure(error):
                report.failures.append(.init(path: path, reason: String(describing: error)))
            case nil:
                report.failures.append(.init(path: path, reason: "not processed"))
            }
        }

        if chains.isEmpty {
            manifest.removeValue(forKey: packManifestKey)
        } else {
            manifest[packManifestKey] = chains
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try data.write(to: packURL, options: .atomic)
        } catch {
            throw UntoldMeshLODError.writeFailed(path: packURL.path, reason: error.localizedDescription)
        }
        return report
    }

    /// Five significant digits are plenty for a switch point, and keep the manifest readable.
    private static func rounded(_ value: Float) -> Double {
        guard value.isFinite, value != 0 else { return 0 }
        let magnitude = pow(10, 4 - floor(log10(abs(Double(value)))))
        return (Double(value) * magnitude).rounded() / magnitude
    }

    private static func fileSize(_ url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}

/// The chains of a pack's models, filled in from several threads.
private final class ChainResults: @unchecked Sendable {
    private let lock = NSLock()
    private let reportLock = NSLock()
    private var results: [Result<UntoldMeshLODChain, Error>?]
    private var done = 0

    init(count: Int) {
        results = Array(repeating: nil, count: count)
    }

    /// Stores a result and returns how many are in.
    func set(_ result: Result<UntoldMeshLODChain, Error>, at index: Int) -> Int {
        lock.withLock {
            results[index] = result
            done += 1
            return done
        }
    }

    func all() -> [Result<UntoldMeshLODChain, Error>?] {
        lock.withLock { results }
    }

    /// Runs one progress callback at a time.
    func report(_ body: () -> Void) {
        reportLock.withLock(body)
    }
}
