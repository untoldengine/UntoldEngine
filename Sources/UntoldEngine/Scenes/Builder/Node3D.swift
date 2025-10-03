//
//  Node3D.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 2/10/25.
//

public class Node3D: Node, NodeTransform
{
    public override init(entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping () -> [any NodeProtocol]) {
        super.init(entityID: entityID, name:name, content: content)
        self.registerTransformComponent()
        UntoldEngine.registerSceneGraphComponent(entityId: self.entityID)
    }
}
