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
        /// Adds code component support to an existing `project.yml`: the `UntoldComponentKit`
        /// product on every target that already depends on the engine, and, where a target
        /// lists `Sources/<Project>` explicitly, the components folder next to it. Targets that
        /// compile all of `Sources` need no source entry. Idempotent; the engine package
        /// reference is never touched, because which engine a project pins is its owner's call.
        static func addingCodeComponents(toYAML yaml: String, projectName: String) -> String {
            var output: [String] = []
            let lines = yaml.components(separatedBy: "\n")
            let projectSources = "- path: Sources/\(projectName)"
            let componentSources = "- path: Sources/\(BuildSystem.pluginsFolderName(forProject: projectName))"

            func indentation(of line: String) -> String {
                String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            }

            var blockIndent: Int?
            var entryIndent = ""
            var blockUsesEngine = false
            var blockHasKit = false

            func closeDependenciesBlock() {
                if blockIndent != nil, blockUsesEngine, blockHasKit == false {
                    // Insert after the block's last content line, before any blank lines.
                    var insertAt = output.count
                    while insertAt > 0, output[insertAt - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                        insertAt -= 1
                    }
                    output.insert(contentsOf: [
                        "\(entryIndent)- package: UntoldEngine",
                        "\(entryIndent)  product: UntoldComponentKit",
                    ], at: insertAt)
                }
                blockIndent = nil
                blockUsesEngine = false
                blockHasKit = false
            }

            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let indent = indentation(of: line).count

                if let current = blockIndent, trimmed.isEmpty == false, indent <= current {
                    closeDependenciesBlock()
                }

                if blockIndent != nil {
                    if trimmed == "- package: UntoldEngine" {
                        blockUsesEngine = true
                        entryIndent = indentation(of: line)
                    } else if trimmed == "product: UntoldComponentKit" {
                        blockHasKit = true
                    }
                } else if trimmed == "dependencies:" {
                    blockIndent = indent
                }

                output.append(line)

                if trimmed == projectSources {
                    let next = index + 1 < lines.count ? lines[index + 1].trimmingCharacters(in: .whitespaces) : ""
                    if next != componentSources {
                        let lead = indentation(of: line)
                        output.append("\(lead)\(componentSources)")
                        output.append("\(lead)  optional: true")
                    }
                }
            }
            closeDependenciesBlock()
            return output.joined(separator: "\n")
        }

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
            UNTOLD_ENGINE_PACKAGE_ROOT: "$(BUILD_DIR)/../../SourcePackages/checkouts/UntoldEngine"
            MTL_HEADER_SEARCH_PATHS: "$(inherited) $(UNTOLD_ENGINE_PACKAGE_ROOT)/Sources/UntoldEngineShaderSupport/include"
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

            // Release always builds optimized. `settings.optimizationLevel` is not consulted
            // here: a "Release" configuration that compiles at `-Onone` defeats its purpose, so
            // it must never depend on a caller-supplied default (see BuildSettings.optimizationLevel).
            let releaseOptLevel = "-O"

            // Build configs section
            var releaseConfig = """
            SWIFT_COMPILATION_MODE: wholemodule
            SWIFT_OPTIMIZATION_LEVEL: \(releaseOptLevel)
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

            // Build sources section. Storyboards under Base.lproj are compiled
            // from the Sources tree; do not add Base.lproj as a raw folder
            // resource or the app bundle will contain an uncompiled storyboard.
            let sourcesSection = """
                sources:
                  - path: Sources
                    excludes:
                      - "\(settings.projectName)/GameData"
                  - path: Sources/\(settings.projectName)/GameData
                    type: folder
                    buildPhase: resources
            """

            // Packages section
            let enginePackage = settings.resolvedEnginePackage
            let packagesSection = """
            packages:
              UntoldEngine:
                url: \(enginePackage.url)
                \(enginePackage.xcodeGenRequirement)
            """

            // Dependencies section
            let dependenciesSection: String
            if case .visionOS = settings.target {
                dependenciesSection = """
                    dependencies:
                      - package: UntoldEngine
                        product: UntoldEngineXR
                      - package: UntoldEngine
                        product: UntoldEngineAR
                """
            } else if settings.isIOSAR, case .iOS = settings.target {
                dependenciesSection = """
                    dependencies:
                      - package: UntoldEngine
                        product: UntoldEngineAR
                """
            } else {
                dependenciesSection = """
                    dependencies:
                      - package: UntoldEngine
                        product: UntoldEngine
                      - package: UntoldEngine
                        product: UntoldEngineShaderSupport
                """
            }

            // Code components: the kit is one more product of the same engine package.
            let componentKitDependency = """

                  - package: UntoldEngine
                    product: UntoldComponentKit
            """
            let kitDependencyIfEnabled = settings.includesCodeComponents ? componentKitDependency : ""
            let dependenciesWithKit = dependenciesSection + kitDependencyIfEnabled

            // Single-platform projects compile everything under Sources, the components folder
            // included. Multi-platform targets list their folders, so they need it spelled out;
            // `optional` keeps generation working before the folder exists.
            let componentSourcesIfEnabled = settings.includesCodeComponents ? """

                  - path: Sources/\(BuildSystem.pluginsFolderName(forProject: settings.projectName))
                    optional: true
            """ : ""

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
                    url: \(enginePackage.url)
                    \(enginePackage.xcodeGenRequirement)

                targets:
                  \(settings.projectName) macOS:
                    type: application
                    platform: macOS
                    deploymentTarget: \(macOSVersion.rawValue)
                    sources:
                      - path: \(settings.projectName) macOS
                      - path: Sources/\(settings.projectName)\(componentSourcesIfEnabled)
                      - path: Sources/\(settings.projectName)/GameData
                        type: folder
                        buildPhase: resources
                \(dependenciesWithKit)
                    settings:
                      base:
                        PRODUCT_BUNDLE_IDENTIFIER: \(settings.bundleIdentifier)
                        SWIFT_VERSION: 5.0
                        MARKETING_VERSION: "1.0"
                        CURRENT_PROJECT_VERSION: "1"
                        INFOPLIST_FILE: \(settings.projectName) macOS/Info.plist
                        UNTOLD_ENGINE_PACKAGE_ROOT: "$(BUILD_DIR)/../../SourcePackages/checkouts/UntoldEngine"
                        MTL_HEADER_SEARCH_PATHS: "$(inherited) $(UNTOLD_ENGINE_PACKAGE_ROOT)/Sources/UntoldEngineShaderSupport/include"\(teamIDLine)
                      configs:
                        Debug:
                          SWIFT_OPTIMIZATION_LEVEL: -Onone
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                        Release:
                          SWIFT_COMPILATION_MODE: wholemodule
                          SWIFT_OPTIMIZATION_LEVEL: \(releaseOptLevel)
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym

                  \(settings.projectName) iOS:
                    type: application
                    platform: iOS
                    deploymentTarget: \(iOSVersion.rawValue)
                    sources:
                      - path: \(settings.projectName) iOS
                      - path: Sources/\(settings.projectName)\(componentSourcesIfEnabled)
                      - path: Sources/\(settings.projectName)/GameData
                        type: folder
                        buildPhase: resources
                    dependencies:
                      - package: UntoldEngine
                        product: UntoldEngine
                      - package: UntoldEngine
                        product: UntoldEngineShaderSupport\(kitDependencyIfEnabled)
                    settings:
                      base:
                        PRODUCT_BUNDLE_IDENTIFIER: \(settings.bundleIdentifier)
                        SWIFT_VERSION: 5.0
                        MARKETING_VERSION: "1.0"
                        CURRENT_PROJECT_VERSION: "1"
                        INFOPLIST_FILE: \(settings.projectName) iOS/Info.plist
                        UNTOLD_ENGINE_PACKAGE_ROOT: "$(BUILD_DIR)/../../SourcePackages/checkouts/UntoldEngine"
                        MTL_HEADER_SEARCH_PATHS: "$(inherited) $(UNTOLD_ENGINE_PACKAGE_ROOT)/Sources/UntoldEngineShaderSupport/include"
                        CODE_SIGN_STYLE: Automatic\(teamIDLine)
                      configs:
                        Debug:
                          SWIFT_OPTIMIZATION_LEVEL: -Onone
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                        Release:
                          SWIFT_COMPILATION_MODE: wholemodule
                          SWIFT_OPTIMIZATION_LEVEL: \(releaseOptLevel)
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym

                  \(settings.projectName) iOS AR:
                    type: application
                    platform: iOS
                    deploymentTarget: \(iOSVersion.rawValue)
                    sources:
                      - path: \(settings.projectName) iOS AR
                      - path: Sources/\(settings.projectName)\(componentSourcesIfEnabled)
                      - path: Sources/\(settings.projectName)/GameData
                        type: folder
                        buildPhase: resources
                    dependencies:
                      - package: UntoldEngine
                        product: UntoldEngineAR\(kitDependencyIfEnabled)
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
                          SWIFT_OPTIMIZATION_LEVEL: \(releaseOptLevel)
                          DEBUG_INFORMATION_FORMAT: dwarf-with-dsym

                  \(settings.projectName) visionOS:
                    type: application
                    platform: visionOS
                    deploymentTarget: \(visionOSVersion.rawValue)
                    sources:
                      - path: \(settings.projectName) visionOS
                      - path: Sources/\(settings.projectName)\(componentSourcesIfEnabled)
                      - path: Sources/\(settings.projectName)/GameData
                        type: folder
                        buildPhase: resources
                    dependencies:
                      - package: UntoldEngine
                        product: UntoldEngineXR
                      - package: UntoldEngine
                        product: UntoldEngineAR\(kitDependencyIfEnabled)
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
                          SWIFT_OPTIMIZATION_LEVEL: \(releaseOptLevel)
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
                \(dependenciesWithKit)
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
