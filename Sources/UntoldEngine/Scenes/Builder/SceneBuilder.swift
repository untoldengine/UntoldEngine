//
//  SceneBuilder.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

@resultBuilder
public struct SceneBuilder
{
    public static func buildBlock() -> [any NodeProtocol] { [] }
    
    // Single node
    public static func buildBlock(_ component: any NodeProtocol) -> [any NodeProtocol] { [component] }

    // Multiple nodes
    public static func buildBlock(_ components: any NodeProtocol...) -> [any NodeProtocol] { components }
    
    // Support conditionals (if/else)
    public static func buildEither(first component : [any NodeProtocol]) -> [any NodeProtocol] { component }
    public static func buildEither(second component: [any NodeProtocol]) -> [any NodeProtocol] { component }

    // Support optionals (if let)
    public static func buildOptional(_ component: [any NodeProtocol]?) -> [any NodeProtocol] { component ?? [] }

    // Support loops
    public static func buildArray(_ components: [[any NodeProtocol]]) -> [any NodeProtocol] { components.flatMap { $0 } }
}
