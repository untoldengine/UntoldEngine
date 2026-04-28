
//
//  AssetDiskCache.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CryptoKit
import Foundation

enum AssetDiskCacheError: Error, Equatable {
    case pathTraversalAttempt(String)
}

/// Persistent disk cache for remote assets.
///
/// `.untold` payloads are content-addressed and never expire — they are evicted
/// only when the cache exceeds its size budget (LRU order).  Manifests (`.json`)
/// are stored with an ETag sidecar so the downloader can issue conditional GET
/// requests and skip re-downloading unchanged files.
///
/// All mutations are actor-isolated; cache reads are safe to call from any Task.
actor AssetDiskCache {
    static let shared = AssetDiskCache()

    // MARK: - Types

    struct CacheEntry {
        let localURL: URL
        let sizeBytes: Int
        var lastAccess: Date
    }

    /// Sidecar metadata persisted alongside manifest files.
    struct ManifestMeta: Codable {
        let remoteURL: String
        let etag: String?
        let cachedAt: Date
    }

    // MARK: - Properties

    private let cacheDir: URL
    private let maxBytes: Int
    private var currentBytes: Int = 0
    private var entries: [String: CacheEntry] = [:]

    // MARK: - Init

    /// Creates a cache instance that uses an explicit directory.
    /// Intended for unit tests — pass a unique temporary directory per test
    /// to get full isolation without touching the shared system cache.
    init(directory: URL, maxBytes: Int) {
        let fm = FileManager.default
        cacheDir = directory
        self.maxBytes = maxBytes

        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            handleError(.cacheDirectoryCreationFailed, error.localizedDescription)
        }

        var scannedEntries: [String: CacheEntry] = [:]
        var scannedBytes = 0
        if let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in contents {
                guard url.pathExtension != "meta", url.pathExtension != "tmp" else { continue }
                let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey])
                let size = attrs?.fileSize ?? 0
                let accessed = attrs?.contentAccessDate ?? Date.distantPast
                let key = url.deletingPathExtension().lastPathComponent
                scannedEntries[key] = CacheEntry(localURL: url, sizeBytes: size, lastAccess: accessed)
                scannedBytes += size
            }
        }
        entries = scannedEntries
        currentBytes = scannedBytes
    }

    /// - Parameter maxBytes: Maximum total cache size on disk. Default 500 MB.
    init(maxBytes: Int = 500 * 1024 * 1024) {
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("UntoldAssetCache", isDirectory: true)
        cacheDir = dir
        self.maxBytes = maxBytes

        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            handleError(.cacheDirectoryCreationFailed, error.localizedDescription)
        }

        // Inline index scan — avoids actor-isolation call from init.
        var scannedEntries: [String: CacheEntry] = [:]
        var scannedBytes = 0
        if let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in contents {
                guard url.pathExtension != "meta", url.pathExtension != "tmp" else { continue }
                let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey])
                let size = attrs?.fileSize ?? 0
                let accessed = attrs?.contentAccessDate ?? Date.distantPast
                let key = url.deletingPathExtension().lastPathComponent
                scannedEntries[key] = CacheEntry(localURL: url, sizeBytes: size, lastAccess: accessed)
                scannedBytes += size
            }
        }
        entries = scannedEntries
        currentBytes = scannedBytes
    }

    // MARK: - Public API

    /// The root directory of the cache.  Used by `RemoteAssetDownloader` to
    /// resolve relative texture paths after a `.untold` file is cached there.
    var cacheDirectory: URL {
        cacheDir
    }

    /// Returns the cached local file URL for `remoteURL`, or `nil` if not present.
    /// Updates the last-access timestamp so LRU eviction keeps hot entries alive.
    func localURL(for remoteURL: URL) -> URL? {
        let key = cacheKey(for: remoteURL)
        guard var entry = entries[key],
              FileManager.default.fileExists(atPath: entry.localURL.path)
        else {
            entries.removeValue(forKey: key)
            return nil
        }
        entry.lastAccess = Date()
        entries[key] = entry
        return entry.localURL
    }

    /// Returns the stored ETag for `remoteURL`, or `nil` if no sidecar exists.
    func etag(for remoteURL: URL) -> String? {
        let key = cacheKey(for: remoteURL)
        let metaURL = cacheDir.appendingPathComponent(key + ".meta")
        guard let data = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(ManifestMeta.self, from: data)
        else { return nil }
        return meta.etag
    }

    /// Writes `data` to the cache atomically and returns the local file URL.
    ///
    /// - Parameters:
    ///   - data:      Raw bytes to store.
    ///   - remoteURL: The original remote URL used as the cache key.
    ///   - etag:      Optional ETag from the HTTP response; stored in a sidecar
    ///                file so future requests can use conditional GET.
    @discardableResult
    func store(data: Data, for remoteURL: URL, etag: String? = nil) throws -> URL {
        let key = cacheKey(for: remoteURL)
        let ext = remoteURL.pathExtension
        let filename = ext.isEmpty ? key : "\(key).\(ext)"
        let localURL = cacheDir.appendingPathComponent(filename)
        let tmpURL = cacheDir.appendingPathComponent("\(key).tmp")

        // Atomic write: write to tmp, then rename.
        try data.write(to: tmpURL)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        try FileManager.default.moveItem(at: tmpURL, to: localURL)

        // Persist ETag sidecar for manifest revalidation.
        if let etag {
            let meta = ManifestMeta(
                remoteURL: remoteURL.absoluteString,
                etag: etag,
                cachedAt: Date()
            )
            let metaData = try JSONEncoder().encode(meta)
            try metaData.write(to: cacheDir.appendingPathComponent(key + ".meta"))
        }

        let prevSize = entries[key]?.sizeBytes ?? 0
        currentBytes = currentBytes - prevSize + data.count
        entries[key] = CacheEntry(localURL: localURL, sizeBytes: data.count, lastAccess: Date())

        evictIfNeeded()
        return localURL
    }

    /// Stores `data` at a relative path within the cache directory.
    ///
    /// Used for textures referenced inside `.untold` files: they must land at a
    /// predictable relative path (`Textures/foo.png`) so that `NativeFormatLoader`
    /// can find them using the cache directory as its `baseURL`.
    func storeAtRelativePath(_ relativePath: String, data: Data) throws {
        let targetURL = try resolvedCacheURL(forRelativePath: relativePath)
        let dir = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: targetURL)
    }

    /// Returns `true` if a file already exists at `relativePath` inside the cache directory.
    func fileExists(atRelativePath relativePath: String) -> Bool {
        guard let targetURL = try? resolvedCacheURL(forRelativePath: relativePath) else {
            return false
        }
        return FileManager.default.fileExists(atPath: targetURL.path)
    }

    // MARK: - Internals

    private func resolvedCacheURL(forRelativePath relativePath: String) throws -> URL {
        let cacheRoot = cacheDir.standardizedFileURL
        let targetURL = cacheRoot.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = cacheRoot.path
        let targetPath = targetURL.path

        guard targetPath == rootPath || targetPath.hasPrefix(rootPath + "/") else {
            throw AssetDiskCacheError.pathTraversalAttempt(relativePath)
        }

        return targetURL
    }

    /// Builds a stable, filesystem-safe cache key from the full URL string.
    private func cacheKey(for url: URL) -> String {
        let input = Data(url.absoluteString.utf8)
        let digest = SHA256.hash(data: input)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Evicts the least-recently-used entries until usage drops to 75% of the budget.
    private func evictIfNeeded() {
        guard currentBytes > maxBytes else { return }
        let targetBytes = Int(Double(maxBytes) * 0.75)
        let sorted = entries.sorted { $0.value.lastAccess < $1.value.lastAccess }
        for (key, entry) in sorted {
            guard currentBytes > targetBytes else { break }
            try? FileManager.default.removeItem(at: entry.localURL)
            try? FileManager.default.removeItem(at: cacheDir.appendingPathComponent(key + ".meta"))
            currentBytes -= entry.sizeBytes
            entries.removeValue(forKey: key)
            Logger.log(message: "[AssetDiskCache] Evicted \(entry.localURL.lastPathComponent) (\(entry.sizeBytes / 1024) KB).")
        }
    }
}
