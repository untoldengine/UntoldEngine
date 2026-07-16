//
//  StudioCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  StudioCommand.swift
//  UntoldEngineCLI
//
//  Command for installing, updating, and launching Untold Engine Studio
//

import ArgumentParser
import Foundation

struct StudioCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "studio",
        abstract: "Launch, install, or update Untold Engine Studio (the visual editor)",
        discussion: """
        Running 'untoldengine studio' with no subcommand launches the editor,
        offering to install it first if it isn't present.

        Examples:
          # Launch the editor (installs it first if missing)
          untoldengine studio

          # Install the latest release
          untoldengine studio install

          # Install a specific version
          untoldengine studio install --version 0.13.0

          # Update an existing install to the latest release
          untoldengine studio update
        """,
        subcommands: [InstallCommand.self, UpdateCommand.self, LaunchCommand.self]
    )

    /// Running 'untoldengine studio' with no subcommand launches the editor
    func run() async throws {
        try await StudioCommand.launchInstallingIfNeeded()
    }

    static func launchInstallingIfNeeded() async throws {
        if let app = StudioLocator.installedApp() {
            try StudioLauncher.launch(app)
            return
        }

        printWarning("Untold Engine Studio is not installed")
        guard confirm("Install the latest release now?", default: true) else {
            print("You can install it later with:")
            print("  untoldengine studio install")
            return
        }

        let installer = StudioInstaller(force: false, destination: nil)
        let app = try await installer.install(version: nil)
        try StudioLauncher.launch(app)
    }

    // MARK: - Launch

    struct LaunchCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch Untold Engine Studio, installing it first if missing"
        )

        func run() async throws {
            try await StudioCommand.launchInstallingIfNeeded()
        }
    }

    // MARK: - Install

    struct InstallCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Download and install Untold Engine Studio",
            discussion: """
            Downloads the editor from the official GitHub releases and installs it
            into /Applications (or ~/Applications if /Applications is not writable).

            Examples:
              # Install the latest release
              untoldengine studio install

              # Install a specific version
              untoldengine studio install --version 0.13.0

              # Replace an existing install without prompting
              untoldengine studio install --force
            """
        )

        @Option(name: .long, help: "Version to install, e.g. 0.13.0 (default: latest release)")
        var version: String?

        @Option(name: .long, help: "Directory to install into (default: /Applications)")
        var destination: String?

        @Flag(name: .long, help: "Replace an existing install without prompting")
        var force: Bool = false

        func run() async throws {
            printInfo("🎨 Untold Engine Studio Installer")
            print("")

            let installer = StudioInstaller(force: force, destination: destination)
            try await installer.install(version: version)
        }
    }

    // MARK: - Update

    struct UpdateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update",
            abstract: "Update Untold Engine Studio to the latest release"
        )

        func run() async throws {
            guard let app = StudioLocator.installedApp() else {
                printWarning("Untold Engine Studio is not installed")
                print("Install it with:")
                print("  untoldengine studio install")
                return
            }

            let installedVersion = StudioLocator.installedVersion(of: app) ?? "unknown"
            printInfo("Installed version: v\(installedVersion) (\(app.path))")
            printInfo("Checking latest release...")

            let release = try await StudioRelease.fetch(version: nil)
            guard release.version != installedVersion else {
                printSuccess("Already up to date (v\(installedVersion))")
                return
            }

            printInfo("New version available: v\(release.version)")
            guard confirm("Update to v\(release.version)?", default: true) else { return }
            print("")

            let installer = StudioInstaller(force: true, destination: app.deletingLastPathComponent().path)
            try await installer.install(release: release)
        }
    }
}

// MARK: - Locating the Installed App

enum StudioLocator {
    static let appName = "Untold Engine Studio.app"

    static var searchDirectories: [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
    }

    static func installedApp() -> URL? {
        for directory in searchDirectories {
            let app = directory.appendingPathComponent(appName)
            if FileManager.default.fileExists(atPath: app.path) {
                return app
            }
        }
        return nil
    }

    static func installedVersion(of app: URL) -> String? {
        let plistURL = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return nil
        }
        return plist["CFBundleShortVersionString"] as? String
    }
}

// MARK: - Launching

enum StudioLauncher {
    static func launch(_ app: URL) throws {
        printInfo("Launching Untold Engine Studio...")
        let status = try runInheritedProcess(URL(fileURLWithPath: "/usr/bin/open"), [app.path])
        guard status == 0 else {
            throw StudioError.launchFailed(app.path)
        }
    }
}

// MARK: - GitHub Release Metadata

struct StudioRelease: Codable {
    static let repository = "untoldengine/UntoldEditor"

    let tagName: String
    let assets: [Asset]

    struct Asset: Codable {
        let name: String
        let browserDownloadUrl: String
        let size: Int
    }

    /// Tag name without the leading "v", e.g. "0.14.0"
    var version: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    var dmgAsset: Asset? {
        assets.first { $0.name.hasSuffix(".dmg") }
    }

    /// Fetches release metadata from GitHub. Pass nil for the latest release.
    static func fetch(version: String?) async throws -> StudioRelease {
        let endpoint: String
        if let version {
            let normalized = version.hasPrefix("v") ? String(version.dropFirst()) : version
            endpoint = "releases/tags/v\(normalized)"
        } else {
            endpoint = "releases/latest"
        }

        guard let url = URL(string: "https://api.github.com/repos/\(repository)/\(endpoint)") else {
            throw StudioError.invalidURL(endpoint)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StudioError.releaseFetchFailed("No HTTP response from GitHub")
        }

        switch http.statusCode {
        case 200:
            break
        case 404:
            throw StudioError.versionNotFound(version ?? "latest")
        default:
            throw StudioError.releaseFetchFailed("GitHub API returned status \(http.statusCode)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(StudioRelease.self, from: data)
    }
}

// MARK: - Installer

struct StudioInstaller {
    let force: Bool
    let destination: String?

    /// Resolves the requested version against GitHub releases, then installs it.
    @discardableResult
    func install(version: String?) async throws -> URL {
        printInfo(version.map { "Fetching release v\($0)..." } ?? "Fetching latest release...")
        let release = try await StudioRelease.fetch(version: version)
        return try await install(release: release)
    }

    /// Downloads the release DMG and copies the app into the destination directory.
    @discardableResult
    func install(release: StudioRelease) async throws -> URL {
        guard let asset = release.dmgAsset else {
            throw StudioError.noDMGAsset(release.tagName)
        }

        let destinationDir = try resolveDestination()
        let appURL = destinationDir.appendingPathComponent(StudioLocator.appName)

        // Confirm before replacing an existing install
        if FileManager.default.fileExists(atPath: appURL.path), !force {
            let installed = StudioLocator.installedVersion(of: appURL) ?? "unknown"
            let message = "Untold Engine Studio v\(installed) is already installed. Replace with v\(release.version)?"
            guard confirm(message, default: false) else {
                printInfo("Keeping existing installation")
                return appURL
            }
        }

        // Download
        let sizeText = ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file)
        printInfo("Downloading \(asset.name) (\(sizeText))...")

        guard let downloadURL = URL(string: asset.browserDownloadUrl) else {
            throw StudioError.invalidURL(asset.browserDownloadUrl)
        }

        let (tempURL, response) = try await URLSession.shared.download(from: downloadURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw StudioError.downloadFailed("Server returned a non-200 response")
        }

        let dmgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".dmg")
        try FileManager.default.moveItem(at: tempURL, to: dmgURL)
        defer { try? FileManager.default.removeItem(at: dmgURL) }

        printSuccess("Download complete")

        // Mount
        printInfo("Mounting disk image...")
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        try runTool("/usr/bin/hdiutil",
                    ["attach", dmgURL.path, "-nobrowse", "-readonly", "-quiet", "-mountpoint", mountPoint.path],
                    onFailure: { StudioError.mountFailed($0) })
        defer {
            _ = try? runTool("/usr/bin/hdiutil", ["detach", mountPoint.path, "-quiet"], onFailure: { StudioError.mountFailed($0) })
            try? FileManager.default.removeItem(at: mountPoint)
        }

        let mountContents = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
        guard let sourceApp = mountContents.first(where: { $0.pathExtension == "app" }) else {
            throw StudioError.appNotFoundInDMG(asset.name)
        }

        // Copy into place (ditto preserves bundle structure and permissions)
        printInfo("Installing to \(destinationDir.path)...")
        if FileManager.default.fileExists(atPath: appURL.path) {
            try FileManager.default.removeItem(at: appURL)
        }
        try runTool("/usr/bin/ditto", [sourceApp.path, appURL.path], onFailure: { StudioError.copyFailed($0) })

        print("")
        printSuccess("Installed Untold Engine Studio v\(release.version)")
        printInfo(appURL.path)
        print("")
        print("Launch it with:")
        print("  untoldengine studio")
        print("")

        return appURL
    }

    // MARK: - Helpers

    private func resolveDestination() throws -> URL {
        if let destination {
            let url = resolvePath(destination)
            guard validateDirectory(url) else {
                throw StudioError.invalidDestination(url.path)
            }
            return url
        }

        // Prefer replacing an existing install wherever it lives
        if let existing = StudioLocator.installedApp() {
            return existing.deletingLastPathComponent()
        }

        let systemApplications = URL(fileURLWithPath: "/Applications")
        if FileManager.default.isWritableFile(atPath: systemApplications.path) {
            return systemApplications
        }

        printWarning("/Applications is not writable — installing to ~/Applications instead")
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
        try FileManager.default.createDirectory(at: userApplications, withIntermediateDirectories: true)
        return userApplications
    }

    /// Runs a tool capturing stderr, throwing the given error on a non-zero exit.
    private func runTool(_ path: String, _ arguments: [String], onFailure: (String) -> StudioError) throws {
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            throw onFailure(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

// MARK: - Errors

enum StudioError: LocalizedError {
    case invalidURL(String)
    case releaseFetchFailed(String)
    case versionNotFound(String)
    case noDMGAsset(String)
    case downloadFailed(String)
    case mountFailed(String)
    case appNotFoundInDMG(String)
    case invalidDestination(String)
    case copyFailed(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidURL(url):
            return "Invalid URL: \(url)"
        case let .releaseFetchFailed(message):
            return "Failed to fetch release information: \(message)"
        case let .versionNotFound(version):
            return "Release '\(version)' not found. Check available versions at https://github.com/\(StudioRelease.repository)/releases"
        case let .noDMGAsset(tag):
            return "Release \(tag) has no DMG asset"
        case let .downloadFailed(message):
            return "Download failed: \(message)"
        case let .mountFailed(message):
            return "Failed to mount disk image: \(message)"
        case let .appNotFoundInDMG(name):
            return "No app bundle found inside \(name)"
        case let .invalidDestination(path):
            return "Destination is not a directory: \(path)"
        case let .copyFailed(message):
            return "Failed to copy app bundle: \(message)"
        case let .launchFailed(path):
            return "Failed to launch \(path)"
        }
    }
}
