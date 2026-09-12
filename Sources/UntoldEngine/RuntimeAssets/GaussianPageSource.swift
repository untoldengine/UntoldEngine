//
//  GaussianPageSource.swift
//  UntoldEngine
//
//  The byte source a paged `.untoldgs` entity reads its tiers from (`GaussianPageManager`):
//  a protocol for a synchronous, thread-safe range read plus the file identity and index the
//  pager validates against, its file implementation over `pread` on a retained descriptor
//  (`UntoldGSFilePageSource`), and the factory tests replace to inject latency, failures and
//  corruption (`GaussianPageSourceFactory.override`). The same range read serves the tiers of the
//  page pool and the pieces of a file's coarse section (per-chunk-lod-tiers), which the pager
//  reads into the entity's coarse records buffer; the source's index carries the coarse index
//  (`UntoldGSIndex.coarse`) from the open.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// What identifies the file a paged entity was loaded from: its size, inode and modification
/// time. A read that fails, or a periodic reopen after a fault, compares the file against it.
public struct GaussianFileIdentity: Equatable, Sendable {
    public let fileSize: UInt64
    public let inode: UInt64
    public let modificationSeconds: Int64
    public let modificationNanoseconds: Int64

    public init(fileSize: UInt64, inode: UInt64, modificationSeconds: Int64, modificationNanoseconds: Int64) {
        self.fileSize = fileSize
        self.inode = inode
        self.modificationSeconds = modificationSeconds
        self.modificationNanoseconds = modificationNanoseconds
    }

    init(stat status: stat) {
        fileSize = UInt64(max(0, status.st_size))
        inode = UInt64(status.st_ino)
        modificationSeconds = Int64(status.st_mtimespec.tv_sec)
        modificationNanoseconds = Int64(status.st_mtimespec.tv_nsec)
    }
}

/// Why a page read, or a reopen, failed.
public enum GaussianPagingError: Error, Equatable, Sendable {
    /// The read failed with `errno`; the file is unchanged. Retried with a backoff.
    case ioFailure(errno: Int32)
    /// The file ended before the requested range.
    case truncated
    /// The file behind the source is not the one the entity was loaded from (size, inode,
    /// modification time or index differ).
    case fileChanged
    /// A chunk's CRC did not match once it became fully resident.
    case corrupt(chunk: Int)
    /// The source was closed.
    case closed
}

/// A source of `.untoldgs` bytes for the pager: the parsed index, the file's identity, a
/// synchronous range read (called from several worker threads at once), a reopen that
/// re-validates the file after a fault, and a close. Implementations are `Sendable`: their
/// state is immutable or lock-guarded.
public protocol GaussianPageSource: AnyObject, Sendable {
    var index: UntoldGSIndex { get }
    var identity: GaussianFileIdentity { get }
    /// Reads `count` bytes at `offset` into `destination`. Synchronous, thread-safe; throws
    /// `GaussianPagingError`.
    func read(offset: UInt64, count: Int, into destination: UnsafeMutableRawPointer) throws
    /// Opens the file behind the source afresh (a fault's recovery): succeeds when its index
    /// equals the one the source was loaded with — the file's identity is then adopted, so a
    /// byte-identical re-cook resumes — and throws when the index differs or a read still holds
    /// the old descriptor.
    func reopen() throws
    func close()
}

/// The file source: `pread` on a descriptor opened at load and kept for the life of the
/// entity, so an atomic replace (a rename over the file) keeps the old inode readable until
/// a read fails or `reopen()` runs. Validated at open exactly as `UntoldGSFile` validates:
/// header, size against `header.fileSize`, prefix, coarse index and index through
/// `UntoldGSFormat.readIndex`.
public final class UntoldGSFilePageSource: GaussianPageSource, @unchecked Sendable {
    public let url: URL
    public let index: UntoldGSIndex

    private let lock = NSLock()
    private var descriptor: Int32
    private var _identity: GaussianFileIdentity
    private var activeReads = 0
    private var isClosed = false

    public var identity: GaussianFileIdentity {
        lock.lock()
        defer { lock.unlock() }
        return _identity
    }

    public init(url: URL) throws {
        self.url = url
        let opened = try UntoldGSFilePageSource.open(url: url)
        descriptor = opened.descriptor
        _identity = opened.identity
        index = opened.index
    }

    deinit {
        close()
    }

    /// Opens, identifies and validates the file at `url`; the caller owns the descriptor.
    private static func open(url: URL) throws -> (descriptor: Int32, identity: GaussianFileIdentity, index: UntoldGSIndex) {
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else {
            throw UntoldGSError.truncated
        }
        var succeeded = false
        defer {
            if !succeeded { Darwin.close(descriptor) }
        }
        var status = stat()
        guard fstat(descriptor, &status) == 0 else {
            throw GaussianPagingError.ioFailure(errno: errno)
        }
        let identity = GaussianFileIdentity(stat: status)
        // The access pattern is random: no read-ahead.
        _ = fcntl(descriptor, F_RDAHEAD, 0)

        var headerBytes = [UInt8](repeating: 0, count: UntoldGSFormat.headerSize)
        try readFully(descriptor: descriptor, offset: 0, into: &headerBytes)
        let header = try UntoldGSFormat.readHeaderV3(from: Data(headerBytes))
        guard identity.fileSize == header.fileSize else {
            throw UntoldGSError.sizeMismatch("file has \(identity.fileSize) bytes, header declares \(header.fileSize)")
        }
        // The prefix through the tree and, when the file carries coarse levels, the coarse index
        // after the fine payloads: two bounded reads, never a payload.
        let index = try UntoldGSFormat.readIndex(header: header) { offset, count in
            var bytes = [UInt8](repeating: 0, count: count)
            try readFully(descriptor: descriptor, offset: offset, into: &bytes)
            return Data(bytes)
        }
        succeeded = true
        return (descriptor, identity, index)
    }

    private static func readFully(descriptor: Int32, offset: UInt64, into bytes: inout [UInt8]) throws {
        let count = bytes.count
        try bytes.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var done = 0
            while done < count {
                let got = pread(descriptor, base + done, count - done, off_t(offset) + off_t(done))
                if got < 0 {
                    if errno == EINTR { continue }
                    throw GaussianPagingError.ioFailure(errno: errno)
                }
                if got == 0 { throw UntoldGSError.truncated }
                done += got
            }
        }
    }

    public func read(offset: UInt64, count: Int, into destination: UnsafeMutableRawPointer) throws {
        lock.lock()
        guard !isClosed else {
            lock.unlock()
            throw GaussianPagingError.closed
        }
        let descriptor = descriptor
        activeReads += 1
        lock.unlock()
        defer {
            lock.lock()
            activeReads -= 1
            lock.unlock()
        }

        var done = 0
        while done < count {
            let got = pread(descriptor, destination + done, count - done, off_t(offset) + off_t(done))
            if got < 0 {
                let code = errno
                if code == EINTR { continue }
                throw failure(descriptor: descriptor, fallback: .ioFailure(errno: code))
            }
            if got == 0 {
                throw failure(descriptor: descriptor, fallback: .truncated)
            }
            done += got
        }
    }

    /// A failed read is `.fileChanged` when the file behind the descriptor no longer matches
    /// the identity the entity was loaded with, else `fallback`.
    private func failure(descriptor: Int32, fallback: GaussianPagingError) -> GaussianPagingError {
        var status = stat()
        guard fstat(descriptor, &status) == 0 else { return fallback }
        return GaussianFileIdentity(stat: status) == identity ? fallback : .fileChanged
    }

    public func reopen() throws {
        let opened = try UntoldGSFilePageSource.open(url: url)
        guard opened.index == index else {
            Darwin.close(opened.descriptor)
            throw GaussianPagingError.fileChanged
        }
        lock.lock()
        guard !isClosed else {
            lock.unlock()
            Darwin.close(opened.descriptor)
            throw GaussianPagingError.closed
        }
        // A read still on the old descriptor keeps it: try again at the next reopen.
        guard activeReads == 0 else {
            lock.unlock()
            Darwin.close(opened.descriptor)
            throw GaussianPagingError.ioFailure(errno: EBUSY)
        }
        let previous = descriptor
        descriptor = opened.descriptor
        _identity = opened.identity
        lock.unlock()
        Darwin.close(previous)
    }

    public func close() {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return }
        isClosed = true
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }
    }
}

/// Where a paged load gets its source. Tests install `override` (saved and restored around the
/// test, like the injected HZB); the default opens `UntoldGSFilePageSource(url:)`.
public enum GaussianPageSourceFactory {
    public static var override: (@Sendable (URL) throws -> any GaussianPageSource)? {
        get { storage.override }
        set { storage.override = newValue }
    }

    public static func make(_ url: URL) throws -> any GaussianPageSource {
        if let override {
            return try override(url)
        }
        return try UntoldGSFilePageSource(url: url)
    }

    private final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var _override: (@Sendable (URL) throws -> any GaussianPageSource)?
        var override: (@Sendable (URL) throws -> any GaussianPageSource)? {
            get { lock.lock(); defer { lock.unlock() }; return _override }
            set { lock.lock(); _override = newValue; lock.unlock() }
        }
    }

    private static let storage = Storage()
}
