//
//  Node+Animations.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

public protocol NodeAnimations : NodeProtocol
{
    func setAnimations ( resource:String, name:String ) -> Self
    func changeAnimation ( name:String, withPause pause: Bool ) -> Self
}


extension NodeAnimations
{
    public func setAnimations ( resource:String, name:String ) -> Self {
        setEntityAnimations(entityId: entityID, filename: resource.filename, withExtension: resource.extensionName, name: "running")
        return self
    }

    public func changeAnimation ( name:String, withPause pause: Bool = false ) -> Self {
        UntoldEngine.changeAnimation(entityId: entityID, name: name, withPause: pause )
        return self
    }
}
