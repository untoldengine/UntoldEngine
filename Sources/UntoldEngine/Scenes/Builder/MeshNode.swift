//
//  MeshNode.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
import SwiftUI

@MainActor
public class MeshNode: Node, NodeAnimations, NodeKinetics, NodeMaterial {
    public convenience init(resource: String, entityID: EntityID? = nil, name: String? = nil) {
        self.init(resource: resource, entityID: entityID, name: name) {}
    }

    public convenience init(resource: String, entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping @MainActor () -> [any NodeProtocol]) {
        self.init(entityID: entityID, name: name, content: content)

        if name == nil { setEntityName(entityId: self.entityID, name: resource) }

        setEntityMeshAsync(entityId: self.entityID, filename: resource.filename, withExtension: resource.extensionName)
    }
}
