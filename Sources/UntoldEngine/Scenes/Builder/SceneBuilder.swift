//
//  SceneBuilder.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@resultBuilder
public struct SceneBuilder {
    public static func buildBlock() -> [any NodeProtocol] {
        []
    }

    /// Lift each expression to a component so single nodes and for-loop
    /// results (both `[any NodeProtocol]`) can be combined in the same block.
    public static func buildExpression(_ node: any NodeProtocol) -> [any NodeProtocol] {
        [node]
    }

    public static func buildExpression(_ nodes: [any NodeProtocol]) -> [any NodeProtocol] {
        nodes
    }

    public static func buildBlock(_ components: [any NodeProtocol]...) -> [any NodeProtocol] {
        components.flatMap { $0 }
    }

    /// Support conditionals (if/else)
    public static func buildEither(first component: [any NodeProtocol]) -> [any NodeProtocol] {
        component
    }

    public static func buildEither(second component: [any NodeProtocol]) -> [any NodeProtocol] {
        component
    }

    /// Support optionals (if let)
    public static func buildOptional(_ component: [any NodeProtocol]?) -> [any NodeProtocol] {
        component ?? []
    }

    /// Support loops
    public static func buildArray(_ components: [[any NodeProtocol]]) -> [any NodeProtocol] {
        components.flatMap { $0 }
    }
}
