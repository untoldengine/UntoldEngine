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
        abstract: "Install everything the exporter pipeline needs (e.g. astcenc, Pillow, lz4)",
        discussion: """
        Downloads, verifies, and installs the external tools and Python
        packages that `untoldengine export --optimize` and `untoldengine
        texbake` rely on, so you don't have to hunt down releases or run pip
        install by hand.

        Example:
          untoldengine bootstrap
        """
    )

    @Flag(name: .long, help: "Reinstall even if already present")
    var force = false

    private var dependencies: [any BootstrapDependency] {
        [
            AstcencDependency(),
            PipPackageDependency(name: "Pillow", importName: "PIL", pipSpec: "Pillow"),
            PipPackageDependency(name: "lz4", importName: "lz4", pipSpec: "lz4"),
            BlenderPythonPackageDependency(name: "lz4 (for Blender)", importName: "lz4.block", pipSpec: "lz4"),
        ]
    }

    func run() async throws {
        for dependency in dependencies {
            try await install(dependency)
        }
    }

    private func install(_ dependency: any BootstrapDependency) async throws {
        if !force, dependency.isInstalled() {
            printSuccess("\(dependency.name) already installed (\(dependency.statusDetail))")
            return
        }

        printInfo("Installing \(dependency.name)...")
        try await dependency.install()

        guard dependency.isInstalled() else {
            throw BootstrapError.verificationFailed(dependency.name)
        }
        printSuccess("Installed \(dependency.name) (\(dependency.statusDetail))")
    }
}

// MARK: - Dependency model

/// A single external tool or package that `bootstrap` knows how to install.
/// Add a new type conforming to this protocol and list it in
/// `BootstrapCommand.dependencies` to bootstrap another dependency.
protocol BootstrapDependency {
    var name: String { get }

    /// Whether the dependency is already present and usable.
    func isInstalled() -> Bool

    /// Installs the dependency. Only called when `isInstalled()` returned
    /// false (or `--force` was passed) — implementations don't need to
    /// re-check.
    func install() async throws

    /// Human-readable detail (path, version, etc.) shown after `isInstalled()`
    /// succeeds, either before or after installation.
    var statusDetail: String { get }
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

    var statusDetail: String {
        "\(version): \(installedBinaryURL.path)"
    }

    func isInstalled() -> Bool {
        guard FileManager.default.isExecutableFile(atPath: installedBinaryURL.path) else { return false }
        let installedVersion = try? String(contentsOf: versionMarkerURL, encoding: .utf8)
        return installedVersion?.trimmingCharacters(in: .whitespacesAndNewlines) == version
    }

    func install() async throws {
        guard let asset = assetForCurrentPlatform() else {
            throw BootstrapError.unsupportedPlatform(name)
        }

        let zipURL = try await download(from: asset.url)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        try verifyChecksum(of: zipURL, expected: asset.sha256)
        try extractAndInstall(from: zipURL)
    }

    private func assetForCurrentPlatform() -> (url: URL, sha256: String)? {
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

    private func verifyChecksum(of fileURL: URL, expected: String) throws {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
            throw BootstrapError.checksumMismatch(name: name, expected: expected, actual: actual)
        }
    }

    private func extractAndInstall(from zipURL: URL) throws {
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

// MARK: - Python packages (Pillow, lz4, ...)

/// Installs a single Python package via `pip install --user` and verifies it
/// importable by whatever python3 `untoldengine texbake` will itself resolve
/// (env override, then PATH — see resolvePython3() in TexbakeCommand.swift).
struct PipPackageDependency: BootstrapDependency {
    let name: String
    let importName: String
    let pipSpec: String

    var statusDetail: String {
        "importable by python3 as '\(importName)'"
    }

    func isInstalled() -> Bool {
        canImport(importName)
    }

    func install() async throws {
        let python3URL = try resolvePython3()
        // `pip install --user` is rejected inside a venv/virtualenv (site-packages
        // are already isolated there, and --user has no meaning). Only add it
        // when installing against a system/base Python interpreter.
        var arguments = ["-m", "pip", "install"]
        if !isVirtualEnvironment(python3URL) {
            arguments.append("--user")
        }
        arguments.append(pipSpec)

        let status = try runInheritedProcess(python3URL, arguments)
        guard status == 0 else {
            throw BootstrapError.pipInstallFailed(name: name, status: status)
        }
    }

    private func canImport(_ module: String) -> Bool {
        guard let python3URL = try? resolvePython3() else { return false }
        let process = Process()
        process.executableURL = python3URL
        process.arguments = ["-c", "import \(module)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    private func isVirtualEnvironment(_ python3URL: URL) -> Bool {
        let process = Process()
        process.executableURL = python3URL
        process.arguments = ["-c", "import sys; print(1 if (hasattr(sys, 'real_prefix') or sys.base_prefix != sys.prefix) else 0)"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        return output?.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }
}

// MARK: - Python packages needed inside a running Blender export (lz4, ...)

/// Directory bootstrap-managed Blender-context packages are installed into:
/// ~/.untoldengine/tools/blender-python-packages (override with UNTOLDENGINE_HOME).
/// Read by scripts/untoldexplorer.py, which inserts it into sys.path itself before
/// importing — see the note on BlenderPythonPackageDependency below for why.
func blenderPythonPackagesDirectory() -> URL {
    untoldEngineToolsDirectory().appendingPathComponent("blender-python-packages", isDirectory: true)
}

/// Installs a package for use *inside a running Blender export*, not the system
/// python3 `PipPackageDependency` targets.
///
/// `untoldengine export` launches Blender with `--factory-startup`, which excludes
/// Python's user site-packages from `sys.path` — so a plain `pip install --user`
/// (even one run against Blender's own bundled python3) is invisible to the actual
/// export. Blender's embedded interpreter also ignores the `PYTHONPATH` environment
/// variable entirely, so that can't inject it either. The only reliable path: `pip
/// install --target` into a fixed directory using Blender's own bundled python3 (for
/// ABI compatibility with compiled extensions like lz4's), with the exporter script
/// itself adding that directory to `sys.path` right before the import — see
/// `_compress_geometry_chunks` in scripts/untoldexplorer.py.
struct BlenderPythonPackageDependency: BootstrapDependency {
    let name: String
    let importName: String
    let pipSpec: String

    private var installDirectory: URL { blenderPythonPackagesDirectory() }

    var statusDetail: String {
        "importable by Blender's bundled python3 (target: \(installDirectory.path))"
    }

    func isInstalled() -> Bool {
        guard let blenderPython3 = try? resolveBlenderPython3(override: nil) else { return false }
        let process = Process()
        process.executableURL = blenderPython3
        // -I (isolated mode) disables user site-packages, replicating the sys.path
        // Blender itself builds when `untoldengine export` launches it with
        // --factory-startup. Without -I this check is a false positive whenever the
        // package happens to be importable some other way (e.g. user site-packages)
        // that won't actually be on sys.path during a real export.
        process.arguments = ["-I", "-c", "import sys; sys.path.insert(0, \(installDirectory.path.debugDescription)); import \(importName)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    func install() async throws {
        let blenderPython3 = try resolveBlenderPython3(override: nil)
        try FileManager.default.createDirectory(at: installDirectory, withIntermediateDirectories: true)
        let arguments = ["-m", "pip", "install", "--target", installDirectory.path, pipSpec]
        let status = try runInheritedProcess(blenderPython3, arguments)
        guard status == 0 else {
            throw BootstrapError.pipInstallFailed(name: name, status: status)
        }
    }
}

// MARK: - Errors

enum BootstrapError: LocalizedError {
    case unsupportedPlatform(String)
    case downloadFailed(String)
    case checksumMismatch(name: String, expected: String, actual: String)
    case extractionFailed(name: String, message: String)
    case unexpectedArchiveLayout(String)
    case pipInstallFailed(name: String, status: Int32)
    case verificationFailed(String)

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
        case let .pipInstallFailed(name, status):
            return "pip install failed for \(name) with exit status \(status)"
        case let .verificationFailed(name):
            return "\(name) still isn't detected after installing. Check the output above for errors."
        }
    }
}
