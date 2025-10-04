//
//  Node+Kinetics.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
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
