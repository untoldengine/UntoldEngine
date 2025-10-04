//
//  EntityNode.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import simd

public protocol NodeProtocol
{
    var entityID: EntityID { get }
}

open class Node : NodeProtocol
{
    var _entityID: EntityID
    public var entityID: EntityID { _entityID }
    
    public var subNodes: [any NodeProtocol] = []
    
    public init( entityID: EntityID? = nil, name:String? = nil ) {
        self._entityID = entityID ?? createEntity()
        if let n = name { setEntityName(entityId: self.entityID, name: n) }
    }

    public init( entityID: EntityID? = nil, name:String? = nil, @SceneBuilder content: @escaping () -> [any NodeProtocol] ) {
        self._entityID = entityID ?? createEntity()
        if let n = name { setEntityName(entityId: self.entityID, name: n) }
        
        subNodes = content()
        for n in subNodes {
            setParent(childId: n.entityID, parentId: self.entityID)
        }
    }
}

extension String {
    public var filename: String {
        return String( self.split(separator: ".").first ?? "" )
    }
    
    public var extensionName: String {
        return String( self.split(separator: ".").last ?? "" )
    }
}
