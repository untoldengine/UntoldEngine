//
//  checkStaleKernels.swift
//  MetalKernelsStaleCheck
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// SwiftPM does not compile UntoldEngineKernels.metal; the engine target ships prebuilt
// .metallib resources instead (see buildkernels.sh and Package.swift), so an edit to the
// .metal source has no effect on `swift build` and produces no warning on its own.
// UntoldEngineKernels.metal #includes every file in ../Shaders, so the compiled kernel
// actually depends on all of them too — the hash below covers the kernels file and every
// Shaders/*.metal file for that reason, not just the file SwiftPM excludes by name. This
// plugin runs on every build plan and compares that hash against the one buildkernels.sh
// stamped the last time it rebuilt the metallibs, so a stale shader binary is surfaced
// instead of running silently.

import CryptoKit
import Foundation
import PackagePlugin

@main
struct MetalKernelsStaleCheck: BuildToolPlugin {
    /// `Target.directoryURL` needs PackageDescription 6.1; this package is on 6.0, so
    /// `.directory` (deprecated `Path`) is the only way to locate the target on this
    /// tools version. SwiftPM invokes this method through the `BuildToolPlugin`
    /// existential at runtime rather than our code calling it directly, so marking it
    /// deprecated silences the unavoidable warning here without anyone needing to call
    /// a deprecated entry point themselves.
    @available(*, deprecated)
    func createBuildCommands(context _: PluginContext, target: Target) async throws -> [Command] {
        let engineDir = URL(fileURLWithPath: target.directory.string)
        let kernelsDir = engineDir.appending(path: "UntoldEngineKernels")
        let shadersDir = engineDir.appending(path: "Shaders")
        let metalSource = kernelsDir.appending(path: "UntoldEngineKernels.metal")
        let hashFile = kernelsDir.appending(path: ".metalsource.sha256")

        guard let kernelsData = try? Data(contentsOf: metalSource) else {
            return []
        }

        let shaderFileNames = (try? FileManager.default.contentsOfDirectory(atPath: shadersDir.path))?
            .filter { $0.hasSuffix(".metal") }
            .sorted() ?? []

        var combined = kernelsData
        for name in shaderFileNames {
            guard let data = try? Data(contentsOf: shadersDir.appending(path: name)) else { return [] }
            combined.append(data)
        }

        let currentHash = SHA256.hash(data: combined).map { String(format: "%02x", $0) }.joined()
        let storedHash = (try? String(contentsOf: hashFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if storedHash != currentHash {
            Diagnostics.warning("""
            UntoldEngineKernels.metal or one of the Shaders/*.metal files it includes has \
            changed since the shipped .metallib resources were built (or \
            \(hashFile.lastPathComponent) is missing). `swift build` does not recompile \
            Metal shaders, so this build is running against stale shader binaries. Run \
            ./buildkernels.sh from the package root, then commit the updated .metallib \
            files and \(hashFile.lastPathComponent).
            """)
        }

        return []
    }
}
