//
//  Node+Kinetics.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@MainActor
public protocol NodeKinetics: NodeProtocol {
    func setEntityKinetics() -> Self
}

@MainActor
public extension NodeKinetics {
    func setEntityKinetics() -> Self {
        UntoldEngine.setEntityKinetics(entityId: entityID)
        return self
    }
}
