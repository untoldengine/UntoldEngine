//
//  SceneContextVisibility.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct SceneChannel: OptionSet, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static let contextGeometry = SceneChannel(rawValue: 1 << 0)
    public static let selectableGeometry = SceneChannel(rawValue: 1 << 1)
    public static let preserveIdentity = SceneChannel(rawValue: 1 << 2)
}

private final class SceneChannelVisibilityState: @unchecked Sendable {
    static let shared = SceneChannelVisibilityState()

    private let lock = NSLock()
    private var hiddenChannels: SceneChannel = []

    func setVisible(_ channel: SceneChannel, visible: Bool) {
        lock.lock()
        if visible {
            hiddenChannels.remove(channel)
        } else {
            hiddenChannels.insert(channel)
        }
        lock.unlock()
    }

    func isVisible(_ channels: SceneChannel) -> Bool {
        lock.lock()
        let visible = hiddenChannels.intersection(channels).isEmpty
        lock.unlock()
        return visible
    }

    func reset() {
        lock.lock()
        hiddenChannels = []
        lock.unlock()
    }
}

public let selectableSceneEntityNamePrefix = "NM_"

public func defaultSceneChannels(forName name: String, isRenderable: Bool = true) -> SceneChannel {
    if name.hasPrefix(selectableSceneEntityNamePrefix) {
        return [.selectableGeometry, .preserveIdentity]
    }

    return isRenderable ? .contextGeometry : []
}

public func setEntitySceneChannels(entityId: EntityID, channels: SceneChannel) {
    setEntitySceneChannels(entityId: entityId, channels: channels, usesDefaultChannels: false)
}

func setDefaultEntitySceneChannels(entityId: EntityID, channels: SceneChannel) {
    setEntitySceneChannels(entityId: entityId, channels: channels, usesDefaultChannels: true)
}

private func setEntitySceneChannels(entityId: EntityID, channels: SceneChannel, usesDefaultChannels: Bool) {
    if channels.isEmpty {
        if scene.get(component: EntitySceneChannelsComponent.self, for: entityId) != nil {
            scene.remove(component: EntitySceneChannelsComponent.self, from: entityId)
        }
        return
    }

    if scene.get(component: EntitySceneChannelsComponent.self, for: entityId) == nil {
        registerComponent(entityId: entityId, componentType: EntitySceneChannelsComponent.self)
    }

    if let component = scene.get(component: EntitySceneChannelsComponent.self, for: entityId) {
        component.channels = channels
        component.usesDefaultChannels = usesDefaultChannels
    }
}

public func addEntitySceneChannels(entityId: EntityID, channels: SceneChannel) {
    var current = getEntitySceneChannels(entityId: entityId)
    current.insert(channels)
    setEntitySceneChannels(entityId: entityId, channels: current)
}

public func removeEntitySceneChannels(entityId: EntityID, channels: SceneChannel) {
    guard let component = scene.get(component: EntitySceneChannelsComponent.self, for: entityId) else { return }
    component.channels.remove(channels)
    if component.channels.isEmpty {
        scene.remove(component: EntitySceneChannelsComponent.self, from: entityId)
    }
}

public func getEntitySceneChannels(entityId: EntityID) -> SceneChannel {
    if let component = scene.get(component: EntitySceneChannelsComponent.self, for: entityId) {
        return component.channels
    }

    return fallbackSceneChannels(entityId: entityId)
}

public func hasEntitySceneChannel(entityId: EntityID, channel: SceneChannel) -> Bool {
    getEntitySceneChannels(entityId: entityId).intersection(channel).isEmpty == false
}

public func setSceneChannelVisible(_ channel: SceneChannel, _ visible: Bool) {
    SceneChannelVisibilityState.shared.setVisible(channel, visible: visible)
}

public func getSceneChannelVisible(_ channel: SceneChannel) -> Bool {
    SceneChannelVisibilityState.shared.isVisible(channel)
}

public func resetSceneChannelVisibility() {
    SceneChannelVisibilityState.shared.reset()
}

public func shouldHideSceneEntity(entityId: EntityID) -> Bool {
    !SceneChannelVisibilityState.shared.isVisible(getEntitySceneChannels(entityId: entityId))
}

public func areSceneChannelsVisible(_ channels: SceneChannel) -> Bool {
    SceneChannelVisibilityState.shared.isVisible(channels)
}

public func shouldPreserveSceneEntityIdentity(entityId: EntityID) -> Bool {
    hasEntitySceneChannel(entityId: entityId, channel: .preserveIdentity)
}

public func isSelectableSceneEntity(entityId: EntityID) -> Bool {
    hasEntitySceneChannel(entityId: entityId, channel: .selectableGeometry)
}

public func isNonSelectableSceneContextEntity(entityId: EntityID) -> Bool {
    hasEntitySceneChannel(entityId: entityId, channel: .contextGeometry)
}

/// Compatibility path for entities created outside the normal registration flow.
/// Runtime/streamed entities should receive EntitySceneChannelsComponent eagerly;
/// remove this once all entity creation paths assign scene channels explicitly.
private func fallbackSceneChannels(entityId: EntityID) -> SceneChannel {
    let entityName = getEntityName(entityId: entityId)
    if entityName.hasPrefix(selectableSceneEntityNamePrefix) {
        return defaultSceneChannels(forName: entityName)
    }

    if scene.get(component: RenderComponent.self, for: entityId) != nil ||
        scene.get(component: StreamingComponent.self, for: entityId) != nil
    {
        return defaultSceneChannels(forName: entityName)
    }

    return []
}
