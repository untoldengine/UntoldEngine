//
//  UntoldEngineCLI.swift
//  UntoldEngine
//
//  Command-line tool for creating UntoldEngine game projects
//

import ArgumentParser
import Foundation

@main
struct UntoldEngineCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "untoldengine-create",
        abstract: "Create game projects using UntoldEngine build templates",
        version: "0.1.0",
        subcommands: [CreateCommand.self, UpdateCommand.self],
        defaultSubcommand: CreateCommand.self
    )
}
