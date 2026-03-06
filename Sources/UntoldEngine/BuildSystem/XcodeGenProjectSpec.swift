//
//  XcodeGenProjectSpec.swift
//  UntoldEngine
//
//  Generates XcodeGen project.yml specification as YAML string
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

#if os(macOS)

    /// Generates XcodeGen project specification for game builds
    enum XcodeGenProjectSpec {
        /// Generate project.yml YAML content from build settings
        static func generateYAML(settings: BuildSettings) throws -> String {
            let isMultiPlatform = settings.target.platforms.count > 1
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

            // Add iOS and visionOS code signing settings
            if case .iOS = settings.target {
                baseSettings += """

                CODE_SIGN_STYLE: Automatic
                """
            } else if case .visionOS = settings.target {
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

            // Build sources section - visionOS doesn't use Base.lproj
            var sourcesSection = """
                sources:
                  - path: Sources
                    excludes:
                      - "\(settings.projectName)/GameData"
                  - path: Sources/\(settings.projectName)/GameData
                    type: folder
                    buildPhase: resources
            """

            // Only add Base.lproj for platforms that use storyboards (macOS, iOS)
            if case .macOS = settings.target {
                sourcesSection += """

                      - path: Sources/\(settings.projectName)/Base.lproj
                        type: folder
                        buildPhase: resources
                """
            } else if case .iOS = settings.target {
                sourcesSection += """

                      - path: Sources/\(settings.projectName)/Base.lproj
                        type: folder
                        buildPhase: resources
                """
            }

            // Packages section
            let packagesSection: String
            if settings.isIOSAR, case .iOS = settings.target {
                packagesSection = """
                packages:
                  UntoldEngine:
                    url: https://github.com/untoldengine/UntoldEngine.git
                    branch: develop
                  UntoldEngineAR:
                    url: https://github.com/untoldengine/UntoldEngine.git
                    branch: develop
                """
            } else {
                packagesSection = """
                packages:
                  UntoldEngine:
                    url: https://github.com/untoldengine/UntoldEngine.git
                    branch: develop
                """
            }

            // Dependencies section
            let dependenciesSection: String
            if settings.isIOSAR, case .iOS = settings.target {
                dependenciesSection = """
                    dependencies:
                      - package: UntoldEngine
                      - package: UntoldEngineAR
                """
            } else {
                dependenciesSection = """
                    dependencies:
                      - package: UntoldEngine
                """
            }

            // Assemble final YAML based on multi-platform or single-platform
            let yaml: String

            if isMultiPlatform {
                // Multi-platform: Generate 3 separate targets (macOS, iOS, visionOS)
                guard case let .multi(macOSVersion, iOSVersion, visionOSVersion) = settings.target else {
                    throw BuildError.invalidSettings("Multi-platform target expected")
                }

                // Build team ID line if provided
                let teamIDLine: String
                if let teamID = settings.teamID, !teamID.isEmpty {
                    teamIDLine = "\n        DEVELOPMENT_TEAM: \(teamID)"
                } else {
                    teamIDLine = ""
                }

                // Build packages section for multi-platform (always include AR for iOS AR target)
                yaml = """
                name: \(settings.projectName)

                packages:
                  UntoldEngine:
                    url: https://github.com/untoldengine/UntoldEngine.git
                    branch: develop
                  UntoldEngineXR:
                    url: https://github.com/untoldengine/UntoldEngine.git
                    branch: develop
                  UntoldEngineAR:
                    url: https://github.com/untoldengine/UntoldEngine.git
                    branch: develop

                targets:
                  \(settings.projectName) macOS:
                    type: application
                    platform: macOS
                    deploymentTarget: \(macOSVersion.rawValue)
                    sources:
                      - path: \(settings.projectName) macOS
                      - path: Sources/\(settings.projectName)
                      - path: Sources/\(settings.projectName)/GameData
                        type: folder
                        buildPhase: resources
                \(dependenciesSection)
                    settings:
                      base:
                        PRODUCT_BUNDLE_IDENTIFIER: \(settings.bundleIdentifier)
                        SWIFT_VERSION: 5.0
                        MARKETING_VERSION: "1.0"
                        CURRENT_PROJECT_VERSION: "1"
                        INFOPLIST_FILE: \(settings.projectName) macOS/Info.plist\(teamIDLine)
                      configs:
                        Debug:
                          SWIFT_OPTIMIZATION_LEVEL: -Onone
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                        Release:
                          SWIFT_COMPILATION_MODE: wholemodule
                          SWIFT_OPTIMIZATION_LEVEL: \(optLevel)
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym

                  \(settings.projectName) iOS:
                    type: application
                    platform: iOS
                    deploymentTarget: \(iOSVersion.rawValue)
                    sources:
                      - path: \(settings.projectName) iOS
                      - path: Sources/\(settings.projectName)
                      - path: Sources/\(settings.projectName)/GameData
                        type: folder
                        buildPhase: resources
                    dependencies:
                      - package: UntoldEngine
                    settings:
                      base:
                        PRODUCT_BUNDLE_IDENTIFIER: \(settings.bundleIdentifier)
                        SWIFT_VERSION: 5.0
                        MARKETING_VERSION: "1.0"
                        CURRENT_PROJECT_VERSION: "1"
                        INFOPLIST_FILE: \(settings.projectName) iOS/Info.plist
                        CODE_SIGN_STYLE: Automatic\(teamIDLine)
                      configs:
                        Debug:
                          SWIFT_OPTIMIZATION_LEVEL: -Onone
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                        Release:
                          SWIFT_COMPILATION_MODE: wholemodule
                          SWIFT_OPTIMIZATION_LEVEL: \(optLevel)
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym

                  \(settings.projectName) iOS AR:
                    type: application
                    platform: iOS
                    deploymentTarget: \(iOSVersion.rawValue)
                    sources:
                      - path: \(settings.projectName) iOS AR
                      - path: Sources/\(settings.projectName)
                      - path: Sources/\(settings.projectName)/GameData
                        type: folder
                        buildPhase: resources
                    dependencies:
                      - package: UntoldEngine
                      - package: UntoldEngineAR
                    settings:
                      base:
                        PRODUCT_BUNDLE_IDENTIFIER: \(settings.bundleIdentifier).ar
                        SWIFT_VERSION: 5.0
                        MARKETING_VERSION: "1.0"
                        CURRENT_PROJECT_VERSION: "1"
                        INFOPLIST_FILE: \(settings.projectName) iOS AR/Info.plist
                        CODE_SIGN_STYLE: Automatic\(teamIDLine)
                      configs:
                        Debug:
                          SWIFT_OPTIMIZATION_LEVEL: -Onone
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                        Release:
                          SWIFT_COMPILATION_MODE: wholemodule
                          SWIFT_OPTIMIZATION_LEVEL: \(optLevel)
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym

                  \(settings.projectName) visionOS:
                    type: application
                    platform: visionOS
                    deploymentTarget: \(visionOSVersion.rawValue)
                    sources:
                      - path: \(settings.projectName) visionOS
                      - path: Sources/\(settings.projectName)
                      - path: Sources/\(settings.projectName)/GameData
                        type: folder
                        buildPhase: resources
                    dependencies:
                      - package: UntoldEngine
                      - package: UntoldEngineXR
                    settings:
                      base:
                        PRODUCT_BUNDLE_IDENTIFIER: \(settings.bundleIdentifier)
                        SWIFT_VERSION: 5.0
                        MARKETING_VERSION: "1.0"
                        CURRENT_PROJECT_VERSION: "1"
                        INFOPLIST_FILE: \(settings.projectName) visionOS/Info.plist
                        CODE_SIGN_STYLE: Automatic\(teamIDLine)
                      configs:
                        Debug:
                          SWIFT_OPTIMIZATION_LEVEL: -Onone
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                        Release:
                          SWIFT_COMPILATION_MODE: wholemodule
                          SWIFT_OPTIMIZATION_LEVEL: \(optLevel)
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                """
            } else {
                // Single platform: use simple format
                yaml = """
                name: \(settings.projectName)

                \(packagesSection)

                targets:
                  \(settings.projectName):
                    type: application
                    platform: \(platformName)
                    deploymentTarget: \(deploymentTarget)
                \(sourcesSection)
                \(dependenciesSection)
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
            }

            return yaml
        }
    }

#endif // os(macOS)
