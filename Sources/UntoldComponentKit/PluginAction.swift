//
//  PluginAction.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// A function a plugin exposes: the editor draws it as a button, and USC scripts reach it as
/// `callAction("<TypeName>.<name>")`.
///
///     override class var actions: [PluginAction] {
///         [PluginAction("Jump") { ($0 as? PlayerController)?.jump() }]
///     }
public struct PluginAction {
    public let name: String
    private let body: (ScenePlugin) -> Void

    public init(_ name: String, _ body: @escaping (ScenePlugin) -> Void) {
        self.name = name
        self.body = body
    }

    public func perform(on plugin: ScenePlugin) {
        body(plugin)
    }
}
