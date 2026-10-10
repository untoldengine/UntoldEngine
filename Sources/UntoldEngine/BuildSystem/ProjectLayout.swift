//
//  ProjectLayout.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

#if os(macOS)

    /// Where a project's `GameData` lives, and which of the two folder shapes a
    /// project on disk is using. Projects created before the root-level layout
    /// landed keep `GameData` nested under `Sources/<Project>/GameData`; new
    /// projects (and ones moved over with `untoldengine convert`) hold `GameData`,
    /// `Resources` and `Docs` at the project root, next to `Sources`.
    ///
    /// Everything that locates `GameData` -- the build system, `update`, `assets
    /// install`, the editor -- goes through this type instead of rebuilding the
    /// path shape itself, which is how the category list and the `Sources/<Project>/
    /// GameData` prefix ended up duplicated across the build system, the CLI and the
    /// docs in the first place.
    public struct ProjectLayout: Sendable, Equatable {
        public enum Kind: String, Codable, Sendable {
            /// `GameData` nested under `Sources/<Project>/GameData`.
            case legacy
            /// `GameData`, `Resources` and `Docs` at the project root.
            case rootLevel
        }

        public let kind: Kind
        public let projectRoot: URL
        public let projectName: String

        public init(kind: Kind, projectRoot: URL, projectName: String) {
            self.kind = kind
            self.projectRoot = projectRoot
            self.projectName = projectName
        }

        /// The category folders created under `GameData`. Kept in one place so
        /// `createGameDataDirectories` and `clearGameDataDirectory` can't drift
        /// from each other, or from what `bundleGameData` actually writes into.
        public static let gameDataCategories = [
            "Scenes", "Scripts", "Models", "StreamModels", "Animations", "Gaussians", "Textures", "Shaders", "LUT",
        ]

        public var gameDataDirectory: URL {
            switch kind {
            case .legacy:
                return projectRoot
                    .appendingPathComponent("Sources")
                    .appendingPathComponent(projectName)
                    .appendingPathComponent("GameData")
            case .rootLevel:
                return projectRoot.appendingPathComponent("GameData")
            }
        }

        /// Where artist sources (`.blend`, `.usd`, reference images) live. Only
        /// meaningful for the root-level layout -- a legacy project has no home
        /// for them, which is the problem this layout exists to fix.
        public var resourcesDirectory: URL? {
            kind == .rootLevel ? projectRoot.appendingPathComponent("Resources") : nil
        }

        /// Where project documentation lives. Only meaningful for the root-level layout.
        public var docsDirectory: URL? {
            kind == .rootLevel ? projectRoot.appendingPathComponent("Docs") : nil
        }

        public var sourcesDirectory: URL {
            projectRoot.appendingPathComponent("Sources")
        }

        /// Detects which layout a project on disk is using by checking for a
        /// root-level `GameData` first, falling back to the legacy nested
        /// location. Defaults to `.legacy` if neither exists yet, since that is
        /// the layout new projects are created with today.
        public static func detect(projectRoot: URL, projectName: String) -> ProjectLayout {
            let rootGameData = projectRoot.appendingPathComponent("GameData")
            if FileManager.default.fileExists(atPath: rootGameData.path) {
                return ProjectLayout(kind: .rootLevel, projectRoot: projectRoot, projectName: projectName)
            }
            return ProjectLayout(kind: .legacy, projectRoot: projectRoot, projectName: projectName)
        }
    }

#endif // os(macOS)
