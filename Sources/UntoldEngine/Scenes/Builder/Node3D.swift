//
//  Node3D.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

public class Node3D: Node, NodeTransform
{
    public override init(entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping () -> [any NodeProtocol]) {
        super.init(entityID: entityID, name:name, content: content)
        self.registerTransformComponent()
        UntoldEngine.registerSceneGraphComponent(entityId: self.entityID)
    }
}
