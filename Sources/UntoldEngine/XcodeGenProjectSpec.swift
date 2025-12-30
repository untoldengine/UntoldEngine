//
//  XcodeGenProjectSpec.swift
//  UntoldEngine
//
//  Generates XcodeGen project.yml specification as YAML string
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//

import Foundation

#if os(macOS)

    /// Generates XcodeGen project specification for game builds
    enum XcodeGenProjectSpec {
        /// Generate project.yml YAML content from build settings
        static func generateYAML(settings: BuildSettings) throws -> String {
            let platformName = settings.target.platformName
            let deploymentTarget = settings.target.deploymentTarget

            // Build base settings
            var baseSettings = """
            PRODUCT_BUNDLE_IDENTIFIER: \(settings.bundleIdentifier)
            SWIFT_VERSION: 5.0
            MARKETING_VERSION: "1.0"
            CURRENT_PROJECT_VERSION: "1"
            INFOPLIST_FILE: Sources/\(settings.projectName)/Info.plist
            """

            // Add iOS-specific signing settings
            if case .iOS = settings.target {
                baseSettings += """

                CODE_SIGN_STYLE: Automatic
                """
            }

            // Add team ID if provided
            if let teamID = settings.teamID, !teamID.isEmpty {
                baseSettings += """

                DEVELOPMENT_TEAM: \(teamID)
                """
            }

            // Build optimization level for release
            let optLevel: String
            switch settings.optimizationLevel {
            case .none: optLevel = "-Onone"
            case .speed: optLevel = "-O"
            case .size: optLevel = "-Osize"
            }

            // Build configs section
            var releaseConfig = """
            SWIFT_COMPILATION_MODE: wholemodule
            SWIFT_OPTIMIZATION_LEVEL: \(optLevel)
            """

            if settings.includeDebugInfo {
                releaseConfig += """

                DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                """
            }

            func indent(_ text: String, by spaces: Int) -> String {
                let padding = String(repeating: " ", count: spaces)
                return text
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.isEmpty ? "" : padding + $0 }
                    .joined(separator: "\n")
            }

            // Assemble final YAML
            let yaml = """
            name: \(settings.projectName)

            packages:
              UntoldEngine:
                url: https://github.com/untoldengine/UntoldEngine.git
                branch: develop

            targets:
              \(settings.projectName):
                type: application
                platform: \(platformName)
                deploymentTarget: \(deploymentTarget)
                sources:
                  - path: Sources
                    excludes:
                      - "\(settings.projectName)/GameData"
                  - path: Sources/\(settings.projectName)/GameData
                    type: folder
                    buildPhase: resources
                  - path: Sources/\(settings.projectName)/Base.lproj
                    type: folder
                    buildPhase: resources
                dependencies:
                  - package: UntoldEngine
                settings:
                  base:
            \(indent(baseSettings, by: 16))
                  configs:
                    Debug:
                      SWIFT_OPTIMIZATION_LEVEL: -Onone
                      DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                    Release:
            \(indent(releaseConfig, by: 18))
            """

            return yaml
        }
    }

#endif // os(macOS)
