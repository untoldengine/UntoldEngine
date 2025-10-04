//
//  Node+Animations.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 2/10/25.
//

public protocol NodeAnimations : NodeProtocol
{
    func setAnimations ( resource:String, name:String ) -> Self
    func changeAnimation ( name:String, withPause pause: Bool ) -> Self
}


extension NodeAnimations
{
    public func setAnimations ( resource:String, name:String ) -> Self {
        setEntityAnimations(entityId: entityID, filename: resource.filename, withExtension: resource.extensionName, name: name)
        return self
    }

    public func changeAnimation ( name:String, withPause pause: Bool = false ) -> Self {
        UntoldEngine.changeAnimation(entityId: entityID, name: name, withPause: pause )
        return self
    }
}
