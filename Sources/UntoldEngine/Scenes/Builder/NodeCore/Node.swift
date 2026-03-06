//
//  Node.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd

public protocol NodeProtocol {
    var entityID: EntityID { get }
}

open class Node: NodeProtocol, NodeTransform {
    var _entityID: EntityID
    public var entityID: EntityID { _entityID }

    public var subNodes: [any NodeProtocol] = []

    public init(entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping () -> [any NodeProtocol]) {
        _entityID = entityID ?? createEntity()
        if let n = name { setEntityName(entityId: self.entityID, name: n) }

        subNodes = content()
        for n in subNodes {
            setParent(childId: n.entityID, parentId: self.entityID)
        }
    }

    public convenience init(entityID: EntityID? = nil, name: String? = nil) {
        self.init(entityID: entityID, name: name) {}
    }
}

public extension String {
    var filename: String {
        String(split(separator: ".").first ?? "")
    }

    var extensionName: String {
        String(split(separator: ".").last ?? "")
    }
}
