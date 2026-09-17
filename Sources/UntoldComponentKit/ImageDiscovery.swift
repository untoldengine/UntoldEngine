//
//  ImageDiscovery.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
#if canImport(MachO)
    import MachO
#endif
#if canImport(ObjectiveC)
    import ObjectiveC
#endif

/// Finds classes by asking the Objective-C runtime what a loaded image defines.
///
/// Swift classes are registered with the runtime on Apple platforms even without `@objc`, so
/// this needs no entry point and no hand-maintained list, and it keeps working for classes
/// nothing references in an optimized, dead-stripped binary.
public enum ImageDiscovery {
    /// Classes defined in the image at `imagePath` whose superclass chain reaches `base`.
    /// `base` itself is never returned. Any spelling of the path works: the loader records
    /// images under their resolved path (`/private/var/...` for a file opened as `/var/...`),
    /// so the path is matched against the loaded images first.
    public static func classes(inImageAt imagePath: String, inheritingFrom base: AnyClass) -> [AnyClass] {
        let imageName = loadedImageName(matching: imagePath) ?? imagePath
        var count: UInt32 = 0
        guard let names = objc_copyClassNamesForImage(imageName, &count) else { return [] }
        defer { free(UnsafeMutableRawPointer(mutating: names)) }

        var result: [AnyClass] = []
        for index in 0 ..< Int(count) {
            guard let candidate = objc_lookUpClass(names[index]) else { continue }
            var ancestor: AnyClass? = class_getSuperclass(candidate)
            while let current = ancestor, current != base {
                ancestor = class_getSuperclass(current)
            }
            if ancestor != nil {
                result.append(candidate)
            }
        }
        return result
    }

    /// The name the loader knows a loaded image by, for any path that resolves to the same file.
    public static func loadedImageName(matching path: String) -> String? {
        let target = canonicalPath(path)
        for index in 0 ..< _dyld_image_count() {
            guard let name = _dyld_get_image_name(index) else { continue }
            let candidate = String(cString: name)
            if candidate == path || canonicalPath(candidate) == target {
                return candidate
            }
        }
        return nil
    }

    private static func canonicalPath(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// The path of the image that defines `cls`.
    public static func imagePath(containing cls: AnyClass) -> String? {
        guard let name = class_getImageName(cls) else { return nil }
        return String(cString: name)
    }

    /// The path of the process's main executable.
    public static func mainExecutablePath() -> String? {
        guard let name = _dyld_get_image_name(0) else { return nil }
        return String(cString: name)
    }

    /// The loaded images that are the app itself: the main executable, plus everything loaded
    /// from inside the app bundle.
    ///
    /// The main executable alone is not enough. Xcode builds an app's code into a separate
    /// `<App>.debug.dylib` for debugging and previews and leaves the executable as a stub, and
    /// an app may keep its components in an embedded framework.
    public static func appImagePaths() -> [String] {
        let executable = mainExecutablePath()
        let bundleRoot = canonicalPath(Bundle.main.bundleURL.path) + "/"
        var paths: [String] = []
        for index in 0 ..< _dyld_image_count() {
            guard let name = _dyld_get_image_name(index) else { continue }
            let path = String(cString: name)
            if path == executable || canonicalPath(path).hasPrefix(bundleRoot) {
                paths.append(path)
            }
        }
        return paths
    }
}
