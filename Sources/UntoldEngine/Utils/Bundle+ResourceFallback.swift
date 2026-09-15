//
//  Bundle+ResourceFallback.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

private final class BundleLocatorSentinel {}

public extension Bundle {
    /// A last-resort resource lookup that checks the filesystem directly under
    /// `Bundle.main.resourceURL`, bypassing `Bundle.url(forResource:withExtension:)`'s
    /// internal resource index. Use this alongside that call, not instead of it.
    static func mainResourceURLByPath(forResource name: String, withExtension ext: String? = nil) -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let fileName = ext.map { "\(name).\($0)" } ?? name
        let candidate = resourceURL.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    /// Locates a SwiftPM-generated resource bundle (named "<package>_<target>.bundle") next to
    /// the running code, without the crash risk of that target's generated `Bundle.module`
    /// accessor (which calls `Swift.fatalError()` on a miss -- fatal to the whole app for what
    /// should be a recoverable missing-resource error). `Bundle(url:)` returns nil on a miss
    /// instead, so this is safe to probe unconditionally.
    ///
    /// - Parameters:
    ///   - bundleName: the exact bundle filename SwiftPM generated, e.g. "MyPackage_MyTarget.bundle".
    ///   - anchor: any class defined inside the target whose resource bundle this is. Used
    ///     (via `Bundle(for:)`) to find where that target's own code is actually running from --
    ///     necessary because `Bundle.main` alone doesn't work for every host: a plain executable
    ///     (swift run/CLI tools) has the resource bundle as a sibling of itself, but an XCTest
    ///     run loads this code from a `.xctest` bundle whose OWN sibling (one level up) is where
    ///     SwiftPM actually placed the resource bundle -- `Bundle.main` there is the system
    ///     xctest launcher, not the test bundle, so it can't anchor the search by itself.
    static func safeModuleResourceBundle(named bundleName: String, anchor: AnyClass) -> Bundle? {
        let codeBundleURL = Bundle(for: anchor).bundleURL
        let candidateDirectories = [
            Bundle.main.bundleURL,
            codeBundleURL,
            codeBundleURL.deletingLastPathComponent(),
        ]
        for directory in candidateDirectories {
            if let bundle = Bundle(url: directory.appendingPathComponent(bundleName)) {
                return bundle
            }
        }
        return nil
    }

    /// Resolves a resource from UntoldEngine's own nested SwiftPM resource bundle, without the
    /// crash risk of `Bundle.module`. Returns nil if the bundle isn't present (e.g. a flattened
    /// macOS .app) or doesn't contain the resource.
    static func untoldEngineModuleResourceURL(forResource name: String, withExtension ext: String?) -> URL? {
        safeModuleResourceBundle(named: "UntoldEngine_UntoldEngine.bundle", anchor: BundleLocatorSentinel.self)?
            .url(forResource: name, withExtension: ext)
    }
}
