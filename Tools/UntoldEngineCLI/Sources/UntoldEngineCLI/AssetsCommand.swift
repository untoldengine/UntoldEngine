//
//  AssetsCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import Foundation

struct AssetsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "assets",
        abstract: "Manage asset packs",
        subcommands: [ListCommand.self, InstallCommand.self]
    )

    // MARK: - List

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List available asset packs"
        )

        func run() async throws {
            let manifest = try AssetManifest.load()

            print("")
            print("Available Asset Packs")
            print(String(repeating: "─", count: 40))

            for pack in manifest.assets {
                print("")
                printSuccess("\(pack.id)  v\(pack.version)  (\(pack.size))")
                print("  \(pack.name)")
                print("  \(pack.description)")
            }
            print("")
            print("Install a pack with:")
            print("  untoldengine assets install <id>")
            print("")
        }
    }

    // MARK: - Install

    struct InstallCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Install an asset pack into your project's GameData folder",
            discussion: """
            Searches the current directory for a GameData folder and merges the
            downloaded asset pack into it. Run from your project root or use
            --output to specify the GameData path directly.

            Examples:
              # Auto-detect GameData (run from project root)
              untoldengine assets install starter

              # Specify GameData path explicitly
              untoldengine assets install soccer --output ~/Projects/MyGame/Sources/MyGame/GameData

              # Overwrite existing files without prompting
              untoldengine assets install starter --force
            """
        )

        @Argument(help: "Asset pack ID to install (run 'assets list' to see available packs)")
        var packId: String

        @Option(name: .long, help: "Path to the GameData directory (default: auto-detect from current directory)")
        var output: String?

        @Flag(name: .long, help: "Overwrite existing files without prompting")
        var force: Bool = false

        func run() async throws {
            let manifest = try AssetManifest.load()

            guard let pack = manifest.assets.first(where: { $0.id == packId }) else {
                throw AssetError.packNotFound(packId)
            }

            let gameDataURL = try resolveGameData()
            printInfo("Installing \(pack.name) into: \(gameDataURL.path)")
            print("")

            let installer = AssetInstaller(force: force)
            try await installer.install(pack: pack, into: gameDataURL)
        }

        private func resolveGameData() throws -> URL {
            if let output {
                return resolvePath(output)
            }

            let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let found = findGameDataDirectory(startingAt: currentDir)

            switch found.count {
            case 0:
                throw AssetError.gameDataNotFound
            case 1:
                return found[0]
            default:
                throw AssetError.ambiguousGameData(found)
            }
        }
    }
}
