//
//  UntoldEngineCLI.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser

@main
struct UntoldEngineCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "untoldengine",
        abstract: "UntoldEngine command-line tools",
        version: "0.1.0",
        subcommands: [CreateCommand.self, UpdateCommand.self, AssetsCommand.self, ExportCommand.self, TexbakeCommand.self, BootstrapCommand.self, BlenderAddonCommand.self, StudioCommand.self]
    )
}
