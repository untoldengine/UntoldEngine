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

/// Generates XcodeGen project specification for game builds
enum XcodeGenProjectSpec {
    /// Generate project.yml YAML content from build settings
    static func generateYAML(settings: BuildSettings) throws -> String {
        let platformName = settings.target.platformName
        let deploymentTarget = settings.target.deploymentTarget

        var yaml = """
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
                PRODUCT_BUNDLE_IDENTIFIER: \(settings.bundleIdentifier)
                SWIFT_VERSION: 5.0
                MARKETING_VERSION: "1.0"
                CURRENT_PROJECT_VERSION: "1"
                INFOPLIST_FILE: Sources/\(settings.projectName)/Info.plist
        """

        // Add team ID if provided
        if let teamID = settings.teamID, !teamID.isEmpty {
            yaml += """

                DEVELOPMENT_TEAM: \(teamID)
            """
        }

        // Add configurations
        yaml += """

              configs:
                Debug:
                  SWIFT_OPTIMIZATION_LEVEL: -Onone
                  DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
                Release:
                  SWIFT_COMPILATION_MODE: wholemodule
        """

        // Add optimization level for release
        let optLevel: String
        switch settings.optimizationLevel {
        case .none: optLevel = "-Onone"
        case .speed: optLevel = "-O"
        case .size: optLevel = "-Osize"
        }

        yaml += """

                  SWIFT_OPTIMIZATION_LEVEL: \(optLevel)
        """

        // Add debug info for release if requested
        if settings.includeDebugInfo {
            yaml += """

                  DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
            """
        }

        return yaml
    }
}
