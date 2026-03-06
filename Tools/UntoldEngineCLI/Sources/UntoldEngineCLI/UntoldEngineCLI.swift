//
//  UntoldEngineCLI.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
