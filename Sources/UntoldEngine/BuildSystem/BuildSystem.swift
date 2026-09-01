//
//  BuildSystem.swift
//  UntoldEngine
//
//  Build System - Generates Xcode projects for game distribution
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

#if os(macOS)

    // MARK: - Build Target

    public enum MacOSVersion: String, Codable {
        case v13 = "13.0"
        case v14 = "14.0"
        case v15 = "15.0"
    }

    public enum IOSVersion: String, Codable {
        case v16 = "16.0"
        case v17 = "17.0"
        case v18 = "18.0"
    }

    public enum VisionOSVersion: String, Codable {
        case v1 = "1.0"
        case v2 = "2.0"
        case v26 = "26.0"
    }

    public enum BuildTarget: Codable {
        case macOS(deployment: MacOSVersion)
        case iOS(deployment: IOSVersion)
        case visionOS(deployment: VisionOSVersion)
        case multi(macOS: MacOSVersion, iOS: IOSVersion, visionOS: VisionOSVersion)

        public var platformName: String {
            switch self {
            case .macOS: return "macOS"
            case .iOS: return "iOS"
            case .visionOS: return "visionOS"
            case .multi: return "Multi-Platform"
            }
        }

        public var deploymentTarget: String {
            switch self {
            case let .macOS(version): return version.rawValue
            case let .iOS(version): return version.rawValue
            case let .visionOS(version): return version.rawValue
            case let .multi(macOS, _, _): return macOS.rawValue // Default to macOS version
            }
        }

        public var platforms: [String] {
            switch self {
            case .macOS: return ["macOS"]
            case .iOS: return ["iOS"]
            case .visionOS: return ["visionOS"]
            case .multi: return ["macOS", "iOS", "visionOS"]
            }
        }

        public func deploymentTarget(for platform: String) -> String? {
            switch self {
            case let .macOS(version) where platform == "macOS": return version.rawValue
            case let .iOS(version) where platform == "iOS": return version.rawValue
            case let .visionOS(version) where platform == "visionOS": return version.rawValue
            case let .multi(macOS, iOS, visionOS):
                switch platform {
                case "macOS": return macOS.rawValue
                case "iOS": return iOS.rawValue
                case "visionOS": return visionOS.rawValue
                default: return nil
                }
            default: return nil
            }
        }
    }

    public enum OptimizationLevel: String, Codable {
        case none = "-Onone"
        case speed = "-O"
        case size = "-Osize"
    }

    // MARK: - Build Settings

    public struct BuildSettings: Codable {
        public var projectName: String
        public var bundleIdentifier: String
        public var outputPath: URL
        public var target: BuildTarget
        public var scenes: [String] // Scene file paths
        public var includeDebugInfo: Bool
        public var optimizationLevel: OptimizationLevel
        public var teamID: String? // For code signing
        public var isIOSAR: Bool // Use AR templates for iOS

        public init(
            projectName: String,
            bundleIdentifier: String,
            outputPath: URL,
            target: BuildTarget,
            scenes: [String] = [],
            includeDebugInfo: Bool = true,
            optimizationLevel: OptimizationLevel = .none,
            teamID: String? = nil,
            isIOSAR: Bool = false
        ) {
            self.projectName = projectName
            self.bundleIdentifier = bundleIdentifier
            self.outputPath = outputPath
            self.target = target
            self.scenes = scenes
            self.includeDebugInfo = includeDebugInfo
            self.optimizationLevel = optimizationLevel
            self.teamID = teamID
            self.isIOSAR = isIOSAR
        }
    }

    // MARK: - Build Result

    public struct BuildResult {
        public let xcodeProjectPath: URL
        public let buildTime: TimeInterval
        public let bundledAssets: [String]

        public init(xcodeProjectPath: URL, buildTime: TimeInterval, bundledAssets: [String]) {
            self.xcodeProjectPath = xcodeProjectPath
            self.buildTime = buildTime
            self.bundledAssets = bundledAssets
        }
    }

    public struct UpdateResult {
        public let projectPath: URL
        public let updateTime: TimeInterval
        public let updatedAssets: [String]

        public init(projectPath: URL, updateTime: TimeInterval, updatedAssets: [String]) {
            self.projectPath = projectPath
            self.updateTime = updateTime
            self.updatedAssets = updatedAssets
        }
    }

    public enum BuildError: Error, LocalizedError {
        case invalidSettings(String)
        case templateNotFound
        case assetBundlingFailed(String)
        case projectGenerationFailed(String)
        case fileSystemError(String)
        case projectNotFound(String)
        case invalidProjectStructure(String)

        public var errorDescription: String? {
            switch self {
            case let .invalidSettings(msg): return "Invalid build settings: \(msg)"
            case .templateNotFound: return "Build template not found"
            case let .assetBundlingFailed(msg): return "Asset bundling failed: \(msg)"
            case let .projectGenerationFailed(msg): return "Project generation failed: \(msg)"
            case let .fileSystemError(msg): return "File system error: \(msg)"
            case let .projectNotFound(msg): return "Project not found: \(msg)"
            case let .invalidProjectStructure(msg): return "Invalid project structure: \(msg)"
            }
        }
    }

    // MARK: - Build System

    public class BuildSystem: @unchecked Sendable {
        public static let shared = BuildSystem()
        private init() {}

        /// Check if a project already exists at the output path
        public func projectExists(settings: BuildSettings) -> Bool {
            let projectDir = settings.outputPath.appendingPathComponent(settings.projectName)
            let xcodeProjectPath = projectDir.appendingPathComponent("\(settings.projectName).xcodeproj")
            return FileManager.default.fileExists(atPath: xcodeProjectPath.path)
        }

        /// Validate that an existing project has the expected structure
        public func isValidProjectStructure(settings: BuildSettings) -> Bool {
            let projectDir = settings.outputPath.appendingPathComponent(settings.projectName)
            let gameDataDir = projectDir
                .appendingPathComponent("Sources")
                .appendingPathComponent(settings.projectName)
                .appendingPathComponent("GameData")

            return FileManager.default.fileExists(atPath: gameDataDir.path)
        }

        /// Update only game data in an existing project (preserves custom code)
        public func updateGameData(settings: BuildSettings, progress: ((String) -> Void)? = nil) async throws -> UpdateResult {
            let startTime = Date()

            progress?("🔄 Updating game data for \(settings.projectName)...")

            // 1. Validate that project exists
            guard projectExists(settings: settings) else {
                throw BuildError.projectNotFound("Project not found at \(settings.outputPath.path)")
            }

            // 2. Validate project structure
            let projectDir = settings.outputPath.appendingPathComponent(settings.projectName)
            let gameDataDir = projectDir
                .appendingPathComponent("Sources")
                .appendingPathComponent(settings.projectName)
                .appendingPathComponent("GameData")

            // If GameData doesn't exist, create the directory structure
            if !FileManager.default.fileExists(atPath: gameDataDir.path) {
                progress?("📁 Creating GameData directory structure...")
                try createGameDataDirectories(at: gameDataDir)
            } else {
                // Clear existing GameData contents
                progress?("🗑️ Clearing existing game data...")
                try clearGameDataDirectory(at: gameDataDir)
            }

            progress?("✅ Project structure validated")

            // 3. Bundle fresh game data
            let updatedAssets = try await bundleGameData(to: projectDir, settings: settings)
            progress?("📦 Updated \(updatedAssets.count) assets")

            let updateTime = Date().timeIntervalSince(startTime)
            progress?("✅ Game data updated in \(String(format: "%.2f", updateTime))s")

            return UpdateResult(
                projectPath: projectDir,
                updateTime: updateTime,
                updatedAssets: updatedAssets
            )
        }

        /// Build a game project and generate Xcode project
        public func build(settings: BuildSettings, progress: ((String) -> Void)? = nil) async throws -> BuildResult {
            let startTime = Date()

            progress?("🔨 Starting build for \(settings.target.platformName)...")

            // 1. Validate settings
            try validateSettings(settings)
            progress?("✅ Settings validated")

            // 2. Create output directory
            let projectDir = try createProjectDirectory(settings: settings)
            progress?("📁 Created project directory")

            // 3. Copy template project
            try await copyTemplateProject(to: projectDir, settings: settings)
            progress?("📋 Copied template project")

            // 4. Bundle game data (scenes, scripts, assets)
            let bundledAssets = try await bundleGameData(to: projectDir, settings: settings)
            progress?("📦 Bundled \(bundledAssets.count) assets")

            // 5. Configure Xcode project settings
            try configureProject(at: projectDir, settings: settings)
            progress?("⚙️ Configured Xcode project")

            let buildTime = Date().timeIntervalSince(startTime)
            progress?("✅ Build complete in \(String(format: "%.2f", buildTime))s")

            let xcodeProjectPath = projectDir.appendingPathComponent("\(settings.projectName).xcodeproj")

            return BuildResult(
                xcodeProjectPath: xcodeProjectPath,
                buildTime: buildTime,
                bundledAssets: bundledAssets
            )
        }

        // MARK: - Private Helpers

        private func validateSettings(_ settings: BuildSettings) throws {
            guard !settings.projectName.isEmpty else {
                throw BuildError.invalidSettings("Project name cannot be empty")
            }

            guard !settings.bundleIdentifier.isEmpty else {
                throw BuildError.invalidSettings("Bundle identifier cannot be empty")
            }

            // Validate bundle identifier format
            let bundleIDPattern = "^[a-zA-Z0-9.-]+$"
            let regex = try? NSRegularExpression(pattern: bundleIDPattern)
            let range = NSRange(settings.bundleIdentifier.startIndex..., in: settings.bundleIdentifier)
            guard regex?.firstMatch(in: settings.bundleIdentifier, range: range) != nil else {
                throw BuildError.invalidSettings("Invalid bundle identifier format")
            }
        }

        private func createProjectDirectory(settings: BuildSettings) throws -> URL {
            let projectDir = settings.outputPath.appendingPathComponent(settings.projectName)

            // Remove existing directory if it exists
            if FileManager.default.fileExists(atPath: projectDir.path) {
                try FileManager.default.removeItem(at: projectDir)
            }

            try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

            return projectDir
        }

        private func copyTemplateProject(to projectDir: URL, settings: BuildSettings) async throws {
            // Use embedded templates
            Logger.log(message: "📦 Creating project from embedded templates")
            try createProjectFromEmbeddedTemplates(at: projectDir, settings: settings)

            // Process template variables
            try processTemplateVariables(in: projectDir, settings: settings)

            Logger.log(message: "📋 Template project created successfully")
        }

        private func createProjectFromEmbeddedTemplates(at projectDir: URL, settings: BuildSettings) throws {
            let fileManager = FileManager.default

            // Get template files for the target
            let templateFiles: [String: String]
            if case .multi = settings.target {
                templateFiles = BuildTemplates.getTemplateFilesForMultiPlatform()
            } else if settings.isIOSAR, case .iOS = settings.target {
                templateFiles = BuildTemplates.getTemplateFilesForIOSAR()
            } else {
                templateFiles = BuildTemplates.getTemplateFiles(for: settings.target)
            }

            for (relativePath, content) in templateFiles {
                // Replace {{PROJECT_NAME}} in paths
                let processedPath = relativePath.replacingOccurrences(of: "{{PROJECT_NAME}}", with: settings.projectName)
                let fileURL = projectDir.appendingPathComponent(processedPath)

                // Create intermediate directories
                let dirURL = fileURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

                // Write file content
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }

            // Create GameData directory structure
            // Both single-platform and multi-platform use Sources/{ProjectName}/GameData
            let gameDataDir = projectDir
                .appendingPathComponent("Sources")
                .appendingPathComponent(settings.projectName)
                .appendingPathComponent("GameData")

            try createGameDataDirectories(at: gameDataDir)

            Logger.log(message: "📄 Created \(templateFiles.count) files from embedded templates")

            // Validate iOS project output
            if case .iOS = settings.target {
                try validateIOSProjectOutput(at: projectDir, settings: settings)
            }
        }

        private func bundleGameData(to projectDir: URL, settings: BuildSettings) async throws -> [String] {
            var bundledAssets: [String] = []

            // Both single-platform and multi-platform use Sources/{ProjectName}/GameData
            let gameDataDir = projectDir
                .appendingPathComponent("Sources")
                .appendingPathComponent(settings.projectName)
                .appendingPathComponent("GameData")

            // Create subdirectories
            try createGameDataDirectories(at: gameDataDir)

            // 1. Bundle scenes
            let scenesDir = gameDataDir.appendingPathComponent("Scenes")
            let sceneAssets = try await bundleScene("", to: scenesDir)
            bundledAssets.append(contentsOf: sceneAssets)

            // 2. Bundle USC scripts
            let scriptsDir = gameDataDir.appendingPathComponent("Scripts")
            let scriptAssets = try await bundleScripts(to: scriptsDir)
            bundledAssets.append(contentsOf: scriptAssets)

            // 3. Bundle models, stream models, animations, gaussians, and textures
            let modelsDir = gameDataDir.appendingPathComponent("Models")
            let streamModelsDir = gameDataDir.appendingPathComponent("StreamModels")
            let animationsDir = gameDataDir.appendingPathComponent("Animations")
            let gaussiansDir = gameDataDir.appendingPathComponent("Gaussians")
            let texturesDir = gameDataDir.appendingPathComponent("Textures")
            let assetPaths = try await bundleAssets(modelsDir: modelsDir, streamModelsDir: streamModelsDir, animationsDir: animationsDir, gaussiansDir: gaussiansDir, texturesDir: texturesDir)
            bundledAssets.append(contentsOf: assetPaths)

            // 4. Bundle Metal shaders
            let shadersDir = gameDataDir.appendingPathComponent("Shaders")
            let shaderAssets = try await bundleShaders(to: shadersDir)
            bundledAssets.append(contentsOf: shaderAssets)

            // 5. Bundle color-grade LUTs
            let lutDir = gameDataDir.appendingPathComponent("LUT")
            let lutAssets = try await bundleLUTs(to: lutDir)
            bundledAssets.append(contentsOf: lutAssets)

            Logger.log(message: "📦 Game data bundled to \(gameDataDir.path)")

            return bundledAssets
        }

        private func configureProject(at projectDir: URL, settings: BuildSettings) throws {
            Logger.log(message: "⚙️ Generating Xcode project with XcodeGen...")

            // Generate project.yml YAML
            let yamlContent = try XcodeGenProjectSpec.generateYAML(settings: settings)
            let yamlPath = projectDir.appendingPathComponent("project.yml")
            try yamlContent.write(to: yamlPath, atomically: true, encoding: .utf8)
            Logger.log(message: "📝 Generated project.yml")

            // Call xcodegen command to generate .xcodeproj
            let task = Process()
            task.currentDirectoryURL = projectDir

            // Try to find xcodegen in common locations
            let possiblePaths = [
                "/opt/homebrew/bin/xcodegen",
                "/usr/local/bin/xcodegen",
                "/opt/local/bin/xcodegen",
            ]

            var xcodegenPath: String?
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    xcodegenPath = path
                    break
                }
            }

            guard let xcodegenPath else {
                throw BuildError.projectGenerationFailed("xcodegen not found. Install with: brew install xcodegen")
            }

            task.executableURL = URL(fileURLWithPath: xcodegenPath)
            task.arguments = ["generate"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if task.terminationStatus != 0 {
                    Logger.log(message: "❌ XcodeGen output: \(output)")
                    throw BuildError.projectGenerationFailed("xcodegen failed with status \(task.terminationStatus): \(output)")
                }

                Logger.log(message: "✅ Xcode project generated successfully")
            } catch {
                throw BuildError.projectGenerationFailed("Failed to run xcodegen: \(error.localizedDescription)")
            }

            Logger.log(message: "⚙️ Project configured for \(settings.target.platformName)")
        }

        // MARK: - Template Processing

        private func copyDirectory(from source: URL, to destination: URL) throws {
            let fileManager = FileManager.default

            guard let enumerator = fileManager.enumerator(
                at: source,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw BuildError.fileSystemError("Failed to enumerate template directory")
            }

            for case let fileURL as URL in enumerator {
                let relativePath = fileURL.path.replacingOccurrences(of: source.path + "/", with: "")
                let destinationURL = destination.appendingPathComponent(relativePath)

                // Create intermediate directories
                let destinationDir = destinationURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)

                // Remove existing file if it exists
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }

                // Copy file
                try fileManager.copyItem(at: fileURL, to: destinationURL)
            }
        }

        private func processTemplateVariables(in projectDir: URL, settings: BuildSettings) throws {
            let replacements: [String: String] = [
                "{{PROJECT_NAME}}": settings.projectName,
                "{{BUNDLE_IDENTIFIER}}": settings.bundleIdentifier,
                "{{MACOS_VERSION}}": getMacOSVersionString(settings.target),
            ]

            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: projectDir,
                includingPropertiesForKeys: [.isRegularFileKey]
            ) else {
                return
            }

            for case let fileURL as URL in enumerator {
                // Process text files only
                guard ["swift", "md", "txt"].contains(fileURL.pathExtension) || fileURL.lastPathComponent == "Package.swift" else {
                    continue
                }

                guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    continue
                }

                var modified = false
                for (placeholder, value) in replacements {
                    if content.contains(placeholder) {
                        content = content.replacingOccurrences(of: placeholder, with: value)
                        modified = true
                    }
                }

                if modified {
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            }
        }

        private func getMacOSVersionString(_ target: BuildTarget) -> String {
            switch target {
            case let .macOS(version):
                // Convert "13.0" to "13" for Package.swift
                return version.rawValue.components(separatedBy: ".").first ?? "13"
            default:
                return "13"
            }
        }

        // MARK: - Asset Bundling Helpers

        private func createGameDataDirectories(at gameDataDir: URL) throws {
            let subdirs = ["Scenes", "Scripts", "Models", "StreamModels", "Animations", "Gaussians", "Textures", "Shaders", "LUT"]

            for subdir in subdirs {
                let dirURL = gameDataDir.appendingPathComponent(subdir)
                try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            }
        }

        private func bundleScene(_: String, to scenesDir: URL) async throws -> [String] {
            var bundledScenes: [String] = []
            let fileManager = FileManager.default

            // Copy all scene files from assetBasePath/Scenes
            guard let basePath = assetBasePath else {
                Logger.log(message: "⚠️ Asset base path not set, skipping scene bundling")
                return []
            }

            let scenesSourceDir = basePath.appendingPathComponent("Scenes")

            if fileManager.fileExists(atPath: scenesSourceDir.path) {
                do {
                    let sceneFiles = try fileManager.contentsOfDirectory(at: scenesSourceDir, includingPropertiesForKeys: nil)
                        .filter { $0.pathExtension.lowercased() == "untoldscene" }

                    for sceneFile in sceneFiles {
                        let destURL = scenesDir.appendingPathComponent(sceneFile.lastPathComponent)
                        try fileManager.copyItem(at: sceneFile, to: destURL)
                        bundledScenes.append(destURL.path)
                        Logger.log(message: "🎬 Bundled scene: \(sceneFile.lastPathComponent)")
                    }

                    if bundledScenes.isEmpty {
                        Logger.log(message: "ℹ️  No scene files found in Scenes folder")
                    }
                } catch {
                    Logger.log(message: "⚠️ Failed to bundle scenes: \(error.localizedDescription)")
                    throw BuildError.assetBundlingFailed("Scene bundling failed: \(error.localizedDescription)")
                }
            } else {
                Logger.log(message: "⚠️ Scenes directory not found at: \(scenesSourceDir.path)")
            }

            return bundledScenes
        }

        private func bundleScripts(to scriptsDir: URL) async throws -> [String] {
            var bundledScripts: [String] = []

            // First, try to get scripts from the registry (if loadScripts was called)
            for (_, script) in scriptRegistry {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

                let scriptData = try encoder.encode(script)
                let scriptFileName = "\(script.name).uscript"
                let scriptFileURL = scriptsDir.appendingPathComponent(scriptFileName)

                try scriptData.write(to: scriptFileURL)
                bundledScripts.append(scriptFileURL.path)
                Logger.log(message: "📜 Bundled script from registry: \(scriptFileName)")
            }

            // If no scripts in registry, try to copy from assetBasePath/Scripts
            if bundledScripts.isEmpty, let basePath = assetBasePath {
                let scriptsSourceDir = basePath.appendingPathComponent("Scripts")
                let fileManager = FileManager.default

                if fileManager.fileExists(atPath: scriptsSourceDir.path) {
                    do {
                        let scriptFiles = try fileManager.contentsOfDirectory(at: scriptsSourceDir, includingPropertiesForKeys: nil)
                            .filter { $0.pathExtension.lowercased() == "uscript" }

                        for scriptFile in scriptFiles {
                            let destURL = scriptsDir.appendingPathComponent(scriptFile.lastPathComponent)
                            try fileManager.copyItem(at: scriptFile, to: destURL)
                            bundledScripts.append(destURL.path)
                            Logger.log(message: "📜 Copied script: \(scriptFile.lastPathComponent)")
                        }
                    } catch {
                        Logger.log(message: "⚠️ Failed to copy scripts: \(error.localizedDescription)")
                    }
                }
            }

            if bundledScripts.isEmpty {
                Logger.log(message: "ℹ️  No scripts found to bundle")
            }

            return bundledScripts
        }

        private func bundleAssets(modelsDir: URL, streamModelsDir: URL, animationsDir: URL, gaussiansDir: URL, texturesDir: URL) async throws -> [String] {
            var bundledAssets: [String] = []

            guard let basePath = assetBasePath else {
                Logger.log(message: "⚠️ Asset base path not set, skipping asset bundling")
                return []
            }

            let fileManager = FileManager.default

            // Bundle Models
            let modelsSourceDir = basePath.appendingPathComponent("Models")
            if fileManager.fileExists(atPath: modelsSourceDir.path) {
                do {
                    try copyDirectory(from: modelsSourceDir, to: modelsDir)
                    let copiedFiles = try fileManager.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: nil)
                    bundledAssets.append(contentsOf: copiedFiles.map(\.path))
                    Logger.log(message: "📦 Bundled \(copiedFiles.count) model(s)")
                } catch {
                    Logger.log(message: "⚠️ Failed to bundle models: \(error.localizedDescription)")
                }
            }

            // Bundle Stream Models
            let streamModelsSourceDir = basePath.appendingPathComponent("StreamModels")
            if fileManager.fileExists(atPath: streamModelsSourceDir.path) {
                do {
                    try copyDirectory(from: streamModelsSourceDir, to: streamModelsDir)
                    let copiedFiles = try fileManager.contentsOfDirectory(at: streamModelsDir, includingPropertiesForKeys: nil)
                    bundledAssets.append(contentsOf: copiedFiles.map(\.path))
                    Logger.log(message: "📦 Bundled \(copiedFiles.count) stream model(s)")
                } catch {
                    Logger.log(message: "⚠️ Failed to bundle stream models: \(error.localizedDescription)")
                }
            }

            // Bundle Animations
            let animationsSourceDir = basePath.appendingPathComponent("Animations")
            if fileManager.fileExists(atPath: animationsSourceDir.path) {
                do {
                    try copyDirectory(from: animationsSourceDir, to: animationsDir)
                    let copiedFiles = try fileManager.contentsOfDirectory(at: animationsDir, includingPropertiesForKeys: nil)
                    bundledAssets.append(contentsOf: copiedFiles.map(\.path))
                    Logger.log(message: "🎬 Bundled \(copiedFiles.count) animation(s)")
                } catch {
                    Logger.log(message: "⚠️ Failed to bundle animations: \(error.localizedDescription)")
                }
            }

            // Bundle Materials/Textures
            let materialsSourceDir = basePath.appendingPathComponent("Materials")
            if fileManager.fileExists(atPath: materialsSourceDir.path) {
                do {
                    try copyDirectory(from: materialsSourceDir, to: texturesDir)
                    let copiedFiles = try fileManager.contentsOfDirectory(at: texturesDir, includingPropertiesForKeys: nil)
                    bundledAssets.append(contentsOf: copiedFiles.map(\.path))
                    Logger.log(message: "🎨 Bundled \(copiedFiles.count) material(s)")
                } catch {
                    Logger.log(message: "⚠️ Failed to bundle materials: \(error.localizedDescription)")
                }
            }

            // Bundle HDR files
            let hdrSourceDir = basePath.appendingPathComponent("HDR")
            if fileManager.fileExists(atPath: hdrSourceDir.path) {
                do {
                    let hdrFiles = try fileManager.contentsOfDirectory(at: hdrSourceDir, includingPropertiesForKeys: nil)
                        .filter { $0.pathExtension.lowercased() == "hdr" }

                    for hdrFile in hdrFiles {
                        let destURL = texturesDir.appendingPathComponent(hdrFile.lastPathComponent)
                        try? fileManager.copyItem(at: hdrFile, to: destURL)
                        bundledAssets.append(destURL.path)
                    }

                    if !hdrFiles.isEmpty {
                        Logger.log(message: "🌅 Bundled \(hdrFiles.count) HDR file(s)")
                    }
                } catch {
                    Logger.log(message: "⚠️ Failed to bundle HDR files: \(error.localizedDescription)")
                }
            }

            // Bundle Gaussians
            let gaussiansSourceDir = basePath.appendingPathComponent("Gaussians")
            if fileManager.fileExists(atPath: gaussiansSourceDir.path) {
                do {
                    try copyDirectory(from: gaussiansSourceDir, to: gaussiansDir)
                    let copiedFiles = try fileManager.contentsOfDirectory(at: gaussiansDir, includingPropertiesForKeys: nil)
                    bundledAssets.append(contentsOf: copiedFiles.map(\.path))
                    Logger.log(message: "✨ Bundled \(copiedFiles.count) Gaussian file(s)")
                } catch {
                    Logger.log(message: "⚠️ Failed to bundle Gaussian files: \(error.localizedDescription)")
                }
            }

            return bundledAssets
        }

        /// Bundles standalone .cube color-grade LUTs (see setColorGradeLUT) from
        /// assetBasePath/LUT into the shipped app's GameData/LUT. Separate from
        /// bundleAssets above since LUTs are unrelated to the Models/StreamModels/
        /// Animations/Gaussians/Textures asset group -- a flat copy, like bundleShaders.
        private func bundleLUTs(to lutDir: URL) async throws -> [String] {
            guard let basePath = assetBasePath else {
                Logger.log(message: "⚠️ Asset base path not set, skipping LUT bundling")
                return []
            }

            let fileManager = FileManager.default
            let lutSourceDir = basePath.appendingPathComponent("LUT")
            guard fileManager.fileExists(atPath: lutSourceDir.path) else {
                return []
            }

            do {
                try copyDirectory(from: lutSourceDir, to: lutDir)
                let copiedFiles = try fileManager.contentsOfDirectory(at: lutDir, includingPropertiesForKeys: nil)
                Logger.log(message: "🎞️ Bundled \(copiedFiles.count) LUT(s)")
                return copiedFiles.map(\.path)
            } catch {
                Logger.log(message: "⚠️ Failed to bundle LUTs: \(error.localizedDescription)")
                return []
            }
        }

        private func bundleShaders(to shadersDir: URL) async throws -> [String] {
            // Bundle the compiled Metal shader library
            // The .metallib file should already exist in the engine package

            // Find the UntoldEngineKernels.metallib in the engine
            let enginePath = Bundle.main.bundlePath.components(separatedBy: "/").dropLast(3).joined(separator: "/")
            guard !enginePath.isEmpty else {
                Logger.log(message: "⚠️ Engine path not found, skipping shader bundling")
                return []
            }

            let shaderSourcePath = URL(fileURLWithPath: enginePath)
                .appendingPathComponent("Sources/UntoldEngine/UntoldEngineKernels")

            // Look for .metallib or .air files
            guard let shaderFiles = try? FileManager.default.contentsOfDirectory(
                at: shaderSourcePath,
                includingPropertiesForKeys: nil
            ) else {
                Logger.log(message: "⚠️ Shader directory not found")
                return []
            }

            var bundledShaders: [String] = []

            for shaderFile in shaderFiles where ["metallib", "air"].contains(shaderFile.pathExtension) {
                let destinationURL = shadersDir.appendingPathComponent(shaderFile.lastPathComponent)

                try? FileManager.default.copyItem(at: shaderFile, to: destinationURL)
                bundledShaders.append(destinationURL.path)

                Logger.log(message: "✨ Bundled shader: \(shaderFile.lastPathComponent)")
            }

            return bundledShaders
        }

        /// Clear contents of GameData directory while preserving the directory structure
        private func clearGameDataDirectory(at gameDataDir: URL) throws {
            let fileManager = FileManager.default
            let subdirs = ["Scenes", "Scripts", "Models", "StreamModels", "Animations", "Gaussians", "Textures", "Shaders", "LUT"]

            for subdir in subdirs {
                let dirURL = gameDataDir.appendingPathComponent(subdir)

                // Remove directory if it exists
                if fileManager.fileExists(atPath: dirURL.path) {
                    try fileManager.removeItem(at: dirURL)
                }

                // Recreate empty directory
                try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
            }

            Logger.log(message: "🗑️ Cleared GameData directory contents")
        }

        // MARK: - iOS Project Validation

        /// Validates that iOS project output meets requirements
        private func validateIOSProjectOutput(at projectDir: URL, settings: BuildSettings) throws {
            let infoPlistPath = projectDir
                .appendingPathComponent("Sources")
                .appendingPathComponent(settings.projectName)
                .appendingPathComponent("Info.plist")

            // 1. Verify Info.plist uses $(PRODUCT_BUNDLE_IDENTIFIER)
            if let infoPlistContent = try? String(contentsOf: infoPlistPath, encoding: .utf8) {
                guard infoPlistContent.contains("$(PRODUCT_BUNDLE_IDENTIFIER)") else {
                    throw BuildError.projectGenerationFailed("iOS Info.plist must use $(PRODUCT_BUNDLE_IDENTIFIER) for CFBundleIdentifier")
                }
                Logger.log(message: "✅ iOS Info.plist correctly uses $(PRODUCT_BUNDLE_IDENTIFIER)")
            } else {
                throw BuildError.projectGenerationFailed("Could not read iOS Info.plist for validation")
            }

            // 2. Verify Package.swift does NOT exist in iOS project output
            let packageSwiftPath = projectDir.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageSwiftPath.path) {
                throw BuildError.projectGenerationFailed("Package.swift should not be included in iOS project output")
            }
            Logger.log(message: "✅ iOS project correctly excludes Package.swift")
        }
    }

#endif // os(macOS)
