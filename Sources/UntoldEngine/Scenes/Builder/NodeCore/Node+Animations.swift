//
//  Node+Animations.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public protocol NodeAnimations: NodeProtocol {
    func setAnimations(resource: String, name: String) -> Self
    func changeAnimation(name: String, withPause pause: Bool) -> Self
    func setAnimationPlaybackSpeed(speed: Float) -> Self
}

public extension NodeAnimations {
    func setAnimations(resource: String, name: String) -> Self {
        setEntityAnimations(entityId: entityID, filename: resource.filename, withExtension: resource.extensionName, name: name)
        return self
    }

    func changeAnimation(name: String, withPause pause: Bool = false) -> Self {
        UntoldEngine.changeAnimation(entityId: entityID, name: name, withPause: pause)
        return self
    }

    func setAnimationPlaybackSpeed(speed: Float) -> Self {
        UntoldEngine.setAnimationPlaybackSpeed(entityId: entityID, speed: speed)
        return self
    }
}
