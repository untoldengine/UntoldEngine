
//
//  RemoteAssetDownloader.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Downloads remote assets and commits them to `AssetDiskCache`.
///
/// Concurrent requests for the same URL are deduplicated: the first caller
/// triggers the download; subsequent callers await the same `Task` and receive
/// the result when it completes.  Transient failures are retried up to three
/// times with exponential back-off.  HTTP 304 Not Modified responses return the
/// cached local URL without re-writing to disk.
actor RemoteAssetDownloader {
    static let shared = RemoteAssetDownloader()

    // MARK: - Error

    enum DownloadError: Error, LocalizedError {
        case insecureScheme(String)
        case httpError(Int)
        case cacheEvictedAfter304

        var errorDescription: String? {
            switch self {
            case let .insecureScheme(scheme):
                return "Refusing to download over '\(scheme)': only https:// is permitted"
            case let .httpError(code): return "HTTP \(code)"
            case .cacheEvictedAfter304: return "304 Not Modified but cached file was evicted"
            }
        }
    }

    // MARK: - Properties

    private let session: URLSession
    /// In-flight download tasks, keyed by remote URL.  Used to deduplicate
    /// concurrent requests for the same asset.
    private var inFlight: [URL: Task<URL, Error>] = [:]

    // MARK: - Init

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Returns a local file URL for `remoteURL`, downloading and caching if needed.
    ///
    /// - Throws: `DownloadError` or a `URLError` on network failure.
    func localURL(for remoteURL: URL) async throws -> URL {
        guard remoteURL.scheme?.lowercased() == "https" else {
            throw DownloadError.insecureScheme(remoteURL.scheme?.lowercased() ?? "none")
        }

        // Fast path: already in cache.
        if let cached = await AssetDiskCache.shared.localURL(for: remoteURL) {
            return cached
        }

        // Deduplicate: return the in-flight task if one exists.
        if let existing = inFlight[remoteURL] {
            return try await existing.value
        }

        // Capture session so the Task closure does not capture `self` (actor).
        let session = session
        let task = Task<URL, Error> {
            try await Self.performDownload(url: remoteURL, session: session)
        }
        inFlight[remoteURL] = task

        do {
            let result = try await task.value
            inFlight.removeValue(forKey: remoteURL)
            return result
        } catch {
            inFlight.removeValue(forKey: remoteURL)
            throw error
        }
    }

    // MARK: - Internals

    /// Downloads `url` using `session`, with up to 3 attempts and exponential back-off.
    /// Uses conditional GET (ETag) for manifests that have a cached ETag.
    private static func performDownload(
        url: URL,
        session: URLSession,
        attempt: Int = 0
    ) async throws -> URL {
        var request = URLRequest(url: url)

        // Conditional GET: attach ETag if we have a cached copy.
        if let storedEtag = await AssetDiskCache.shared.etag(for: url) {
            request.setValue(storedEtag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw DownloadError.httpError(-1)
            }

            // 304 Not Modified — reuse the cached local file.
            if http.statusCode == 304 {
                if let cached = await AssetDiskCache.shared.localURL(for: url) {
                    return cached
                }
                // Cache was evicted between the ETag check and the 304 response;
                // retry without the ETag so we get a fresh download.
                throw DownloadError.cacheEvictedAfter304
            }

            guard (200 ... 299).contains(http.statusCode) else {
                throw DownloadError.httpError(http.statusCode)
            }

            let etag = http.value(forHTTPHeaderField: "ETag")
            let localURL = try await AssetDiskCache.shared.store(data: data, for: url, etag: etag)

            Logger.log(message: "[RemoteAssetDownloader] Cached \(url.lastPathComponent) (\(data.count / 1024) KB).")

            // For any .untold asset (tile, HLOD, or LOD level), eagerly download all
            // referenced textures so that NativeFormatLoader can find them at their
            // relative paths inside the cache directory.
            if url.pathExtension == "untold" {
                Logger.log(message: "[RemoteAssetDownloader] Pre-fetching textures for \(url.lastPathComponent).")
                await downloadTextures(in: data, remoteBaseURL: url.deletingLastPathComponent(), session: session)
            }

            return localURL

        } catch {
            if attempt < 2, !Task.isCancelled {
                let delaySecs = pow(2.0, Double(attempt))
                Logger.log(message: "[RemoteAssetDownloader] Attempt \(attempt + 1) failed for \(url.lastPathComponent): \(error). Retrying in \(Int(delaySecs))s.")
                try await Task.sleep(nanoseconds: UInt64(delaySecs) * 1_000_000_000)
                return try await performDownload(url: url, session: session, attempt: attempt + 1)
            }
            Logger.logError(message: "[RemoteAssetDownloader] Failed to download \(url.lastPathComponent) after \(attempt + 1) attempt(s): \(error)")
            throw error
        }
    }

    /// Parses the texture table of a downloaded `.untold` payload and downloads
    /// each referenced texture to its relative path inside the cache directory.
    ///
    /// `NativeFormatLoader` resolves texture URIs relative to the `.untold` file's
    /// directory.  Because the file lands in the cache root (keyed by URL hash),
    /// textures must appear at `<cacheDir>/<textureURI>` — e.g.
    /// `<cacheDir>/Textures/SimpleDungeonTexture.png`.
    private static func downloadTextures(
        in untoldData: Data,
        remoteBaseURL: URL,
        session: URLSession
    ) async {
        // Decode just enough to extract texture URI strings.
        guard let decoded = try? UntoldReader().readAsset(from: untoldData) else {
            Logger.logWarning(message: "[RemoteAssetDownloader] Could not decode texture table for texture pre-fetch.")
            return
        }

        let cache = AssetDiskCache.shared

        for record in decoded.textures {
            guard let uri = try? decoded.string(at: record.uriOffset), !uri.isEmpty else { continue }

            // Skip textures that are already present in the cache directory.
            if await cache.fileExists(atRelativePath: uri) { continue }

            let remoteTextureURL = remoteBaseURL.appendingPathComponent(uri)

            do {
                let (data, response) = try await session.data(from: remoteTextureURL)
                guard let http = response as? HTTPURLResponse,
                      (200 ... 299).contains(http.statusCode)
                else {
                    Logger.logWarning(message: "[RemoteAssetDownloader] Texture fetch returned non-2xx for '\(uri)'.")
                    continue
                }
                try await cache.storeAtRelativePath(uri, data: data)
                Logger.log(message: "[RemoteAssetDownloader] Cached texture '\(uri)' (\(data.count / 1024) KB).")
            } catch {
                Logger.logError(message: "[RemoteAssetDownloader] Failed to fetch texture '\(uri)': \(error)")
            }
        }
    }
}
