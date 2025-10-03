//
//  Node+Kinetics.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 2/10/25.
//

public protocol NodeKinetics : NodeProtocol
{
    func setEntityKinetics() -> Self
}

extension NodeKinetics
{
    public func setEntityKinetics() -> Self {
        UntoldEngine.setEntityKinetics(entityId: entityID)
        return self
    }
}
