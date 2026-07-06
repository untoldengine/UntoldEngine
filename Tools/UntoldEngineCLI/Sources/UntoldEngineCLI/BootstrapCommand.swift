//
//  BootstrapCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import CryptoKit
import Foundation

struct BootstrapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bootstrap",
        abstract: "Install native tools the exporter pipeline needs (e.g. astcenc)",
        discussion: """
        Downloads, verifies, and installs the external command-line tools that
        `untoldengine texbake` relies on into ~/.untoldengine/tools, so you
        don't have to hunt down releases or set environment variables like
        ASTCENC_BIN by hand.

        Example:
          untoldengine bootstrap
        """
    )

    @Flag(name: .long, help: "Reinstall even if the pinned version is already present")
    var force = false

    private var dependencies: [any BootstrapDependency] {
        [AstcencDependency()]
    }

    func run() async throws {
        for dependency in dependencies {
            try await install(dependency)
        }
    }

    private func install(_ dependency: any BootstrapDependency) async throws {
        if !force, dependency.isInstalled() {
            printSuccess("\(dependency.name) \(dependency.version) already installed: \(dependency.installedBinaryURL.path)")
            return
        }

        guard let asset = dependency.assetForCurrentPlatform() else {
            throw BootstrapError.unsupportedPlatform(dependency.name)
        }

        printInfo("Downloading \(dependency.name) \(dependency.version)...")
        let zipURL = try await download(from: asset.url)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        try verifyChecksum(of: zipURL, expected: asset.sha256, name: dependency.name)
        printInfo("Checksum verified")

        printInfo("Installing \(dependency.name) to \(dependency.installedBinaryURL.path)")
        try dependency.install(from: zipURL)

        printSuccess("Installed \(dependency.name) \(dependency.version): \(dependency.installedBinaryURL.path)")
    }

    private func download(from url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BootstrapError.downloadFailed("Server returned a non-200 response for \(url.absoluteString)")
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".zip")
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private func verifyChecksum(of fileURL: URL, expected: String, name: String) throws {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
            throw BootstrapError.checksumMismatch(name: name, expected: expected, actual: actual)
        }
    }
}

// MARK: - Dependency model

/// A single external tool that `bootstrap` knows how to fetch and install.
/// Add a new type conforming to this protocol and list it in
/// `BootstrapCommand.dependencies` to bootstrap another dependency.
protocol BootstrapDependency {
    var name: String { get }
    var version: String { get }
    var installedBinaryURL: URL { get }

    func isInstalled() -> Bool
    func assetForCurrentPlatform() -> (url: URL, sha256: String)?
    func install(from zipURL: URL) throws
}

/// Directory bootstrap-managed tools are installed into: ~/.untoldengine/tools
/// (override with UNTOLDENGINE_HOME). Shared with texbake.py's astcenc lookup.
func untoldEngineToolsDirectory() -> URL {
    if let override = ProcessInfo.processInfo.environment["UNTOLDENGINE_HOME"], !override.isEmpty {
        return resolvePath(override).appendingPathComponent("tools", isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".untoldengine", isDirectory: true)
        .appendingPathComponent("tools", isDirectory: true)
}

// MARK: - astcenc

struct AstcencDependency: BootstrapDependency {
    let name = "astcenc"
    let version = "5.3.0"

    private var installDirectory: URL {
        untoldEngineToolsDirectory().appendingPathComponent(name, isDirectory: true)
    }

    var installedBinaryURL: URL {
        installDirectory.appendingPathComponent(name)
    }

    private var versionMarkerURL: URL {
        installDirectory.appendingPathComponent(".version")
    }

    func isInstalled() -> Bool {
        guard FileManager.default.isExecutableFile(atPath: installedBinaryURL.path) else { return false }
        let installedVersion = try? String(contentsOf: versionMarkerURL, encoding: .utf8)
        return installedVersion?.trimmingCharacters(in: .whitespacesAndNewlines) == version
    }

    func assetForCurrentPlatform() -> (url: URL, sha256: String)? {
        #if os(macOS)
            guard let url = URL(string: "https://github.com/ARM-software/astc-encoder/releases/download/\(version)/astcenc-\(version)-macos-universal.zip") else {
                return nil
            }
            // Published in release-sha256.txt alongside the 5.3.0 GitHub release assets.
            return (url, "ccccba91fe134cc8c4aa70f7d539acb3de9895b656c24e401e562cc1014e6afd")
        #else
            return nil
        #endif
    }

    func install(from zipURL: URL) throws {
        let fm = FileManager.default
        let extractDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: extractDir) }

        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", extractDir.path]
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let msg = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            throw BootstrapError.extractionFailed(name: name, message: msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let extractedBinary = extractDir.appendingPathComponent("bin/astcenc")
        guard fm.fileExists(atPath: extractedBinary.path) else {
            throw BootstrapError.unexpectedArchiveLayout(name)
        }

        try fm.createDirectory(at: installDirectory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: installedBinaryURL.path) {
            try fm.removeItem(at: installedBinaryURL)
        }
        try fm.copyItem(at: extractedBinary, to: installedBinaryURL)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installedBinaryURL.path)

        try version.write(to: versionMarkerURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Errors

enum BootstrapError: LocalizedError {
    case unsupportedPlatform(String)
    case downloadFailed(String)
    case checksumMismatch(name: String, expected: String, actual: String)
    case extractionFailed(name: String, message: String)
    case unexpectedArchiveLayout(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedPlatform(name):
            return "\(name) has no bootstrap download for this platform. See docs/API/Optimizations.md for manual install instructions."
        case let .downloadFailed(message):
            return "Download failed: \(message)"
        case let .checksumMismatch(name, expected, actual):
            return "Checksum mismatch for \(name): expected \(expected), got \(actual). The download may be corrupted; try again."
        case let .extractionFailed(name, message):
            return "Failed to extract \(name): \(message)"
        case let .unexpectedArchiveLayout(name):
            return "\(name) archive did not contain the expected binary layout."
        }
    }
}
