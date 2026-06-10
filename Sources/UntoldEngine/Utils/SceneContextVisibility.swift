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
    public static let ghostGeometry = SceneChannel(rawValue: 1 << 3)
}

public enum SceneChannelRenderMode: Equatable, Sendable {
    case normal
    case hidden
    case wireframe
    case passthroughGhost(opacity: Float)
}

public enum SceneChannelProperty: Sendable {
    case renderMode(SceneChannelRenderMode)
    case pickParticipation(Bool)
}

private final class SceneChannelVisibilityState: @unchecked Sendable {
    static let shared = SceneChannelVisibilityState()

    private let lock = NSLock()
    private var renderModesByChannelRawValue: [UInt64: SceneChannelRenderMode] = [:]

    func setVisible(_ channel: SceneChannel, visible: Bool) {
        setRenderMode(channel, visible ? .normal : .hidden)
    }

    func setRenderMode(_ channel: SceneChannel, _ mode: SceneChannelRenderMode) {
        lock.lock()
        for rawValue in rawChannelValues(in: channel) {
            if mode == .normal {
                renderModesByChannelRawValue.removeValue(forKey: rawValue)
            } else {
                renderModesByChannelRawValue[rawValue] = sanitizedRenderMode(mode)
            }
        }
        lock.unlock()
    }

    func isVisible(_ channels: SceneChannel) -> Bool {
        renderMode(for: channels) != .hidden
    }

    func renderMode(for channels: SceneChannel) -> SceneChannelRenderMode {
        lock.lock()
        let rawValues = rawChannelValues(in: channels)
        let modes = rawValues.compactMap { renderModesByChannelRawValue[$0] }
        lock.unlock()

        var hasHidden = false
        var hasWireframe = false
        var ghostOpacity: Float?
        for mode in modes {
            switch mode {
            case .hidden:
                hasHidden = true
            case .wireframe:
                hasWireframe = true
            case let .passthroughGhost(opacity):
                ghostOpacity = min(ghostOpacity ?? opacity, opacity)
            case .normal:
                continue
            }
        }
        if hasHidden {
            return .hidden
        }
        if hasWireframe {
            return .wireframe
        }
        if let ghostOpacity {
            return .passthroughGhost(opacity: ghostOpacity)
        }
        return .normal
    }

    func reset() {
        lock.lock()
        renderModesByChannelRawValue = [:]
        lock.unlock()
    }

    private func rawChannelValues(in channels: SceneChannel) -> [UInt64] {
        var values: [UInt64] = []
        var remaining = channels.rawValue
        while remaining != 0 {
            let rawValue = remaining & (~remaining &+ 1)
            values.append(rawValue)
            remaining &= ~rawValue
        }
        return values
    }

    private func sanitizedRenderMode(_ mode: SceneChannelRenderMode) -> SceneChannelRenderMode {
        switch mode {
        case let .passthroughGhost(opacity):
            return .passthroughGhost(opacity: min(max(opacity, 0.0), 1.0))
        case .normal, .hidden, .wireframe:
            return mode
        }
    }
}

private final class SceneChannelInteractionState: @unchecked Sendable {
    static let shared = SceneChannelInteractionState()

    private let lock = NSLock()
    private var pickDisabledChannels: SceneChannel = []

    func setPickParticipation(_ channel: SceneChannel, enabled: Bool) {
        lock.lock()
        if enabled {
            pickDisabledChannels.remove(channel)
        } else {
            pickDisabledChannels.insert(channel)
        }
        lock.unlock()
    }

    func isPickEnabled(for channels: SceneChannel) -> Bool {
        lock.lock()
        let disabled = pickDisabledChannels
        lock.unlock()
        return disabled.intersection(channels).isEmpty
    }

    func reset() {
        lock.lock()
        pickDisabledChannels = []
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
            refreshStaticBatchingForSceneChannelChange(entityId: entityId)
        }
        return
    }

    if scene.get(component: EntitySceneChannelsComponent.self, for: entityId) == nil {
        registerComponent(entityId: entityId, componentType: EntitySceneChannelsComponent.self)
    }

    if let component = scene.get(component: EntitySceneChannelsComponent.self, for: entityId) {
        let oldChannels = component.channels
        component.channels = channels
        component.usesDefaultChannels = usesDefaultChannels
        if oldChannels != channels {
            refreshStaticBatchingForSceneChannelChange(entityId: entityId)
        }
    }
}

public func addEntitySceneChannels(entityId: EntityID, channels: SceneChannel) {
    var current = getEntitySceneChannels(entityId: entityId)
    current.insert(channels)
    setEntitySceneChannels(entityId: entityId, channels: current)
}

public func removeEntitySceneChannels(entityId: EntityID, channels: SceneChannel) {
    guard let component = scene.get(component: EntitySceneChannelsComponent.self, for: entityId) else { return }
    let oldChannels = component.channels
    component.channels.remove(channels)
    if component.channels.isEmpty {
        scene.remove(component: EntitySceneChannelsComponent.self, from: entityId)
    }
    if oldChannels != getEntitySceneChannels(entityId: entityId) {
        refreshStaticBatchingForSceneChannelChange(entityId: entityId)
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

public func setSceneChannel(_ channel: SceneChannel, _ property: SceneChannelProperty) {
    switch property {
    case let .renderMode(mode):
        SceneChannelVisibilityState.shared.setRenderMode(channel, mode)
    case let .pickParticipation(enabled):
        SceneChannelInteractionState.shared.setPickParticipation(channel, enabled: enabled)
        markScenePickingDirty(forChannel: channel)
    }
}

public func getSceneChannelRenderMode(_ channel: SceneChannel) -> SceneChannelRenderMode {
    SceneChannelVisibilityState.shared.renderMode(for: channel)
}

public func getSceneChannelVisible(_ channel: SceneChannel) -> Bool {
    SceneChannelVisibilityState.shared.isVisible(channel)
}

public func getSceneChannelPickParticipation(_ channel: SceneChannel) -> Bool {
    SceneChannelInteractionState.shared.isPickEnabled(for: channel)
}

@available(*, deprecated, message: "Use setSceneChannel(_:, .renderMode(_:)) instead")
public func setSceneChannelRenderMode(_ channel: SceneChannel, _ mode: SceneChannelRenderMode) {
    setSceneChannel(channel, .renderMode(mode))
}

@available(*, deprecated, message: "Use setSceneChannel(_:, .renderMode(.normal)) or setSceneChannel(_:, .renderMode(.hidden)) instead")
public func setSceneChannelVisible(_ channel: SceneChannel, _ visible: Bool) {
    setSceneChannel(channel, .renderMode(visible ? .normal : .hidden))
}

public func resetSceneChannelVisibility() {
    SceneChannelVisibilityState.shared.reset()
    SceneChannelInteractionState.shared.reset()
}

public func shouldHideSceneEntity(entityId: EntityID) -> Bool {
    getSceneChannelRenderMode(getEntitySceneChannels(entityId: entityId)) == .hidden
}

public func shouldRenderSceneEntityAsWireframe(entityId: EntityID) -> Bool {
    getSceneChannelRenderMode(getEntitySceneChannels(entityId: entityId)) == .wireframe
}

public func shouldRenderSceneEntityAsPassthroughGhost(entityId: EntityID) -> Bool {
    passthroughGhostOpacity(for: getEntitySceneChannels(entityId: entityId)) != nil
}

public func areSceneChannelsVisible(_ channels: SceneChannel) -> Bool {
    SceneChannelVisibilityState.shared.isVisible(channels)
}

public func areSceneChannelsPickable(_ channels: SceneChannel) -> Bool {
    SceneChannelInteractionState.shared.isPickEnabled(for: channels)
}

/// Whether ray-picking is enabled for `entityId` based solely on its scene channel
/// membership, independent of any per-entity `PickInteractionComponent` override.
public func isSceneEntityPickableByChannel(entityId: EntityID) -> Bool {
    areSceneChannelsPickable(getEntitySceneChannels(entityId: entityId))
}

/// Marks every visible entity belonging to `channel` as pick-dirty so the picking
/// acceleration structures are rebuilt with the updated channel pick state.
private func markScenePickingDirty(forChannel channel: SceneChannel) {
    for entityId in visibleEntityIds where hasEntitySceneChannel(entityId: entityId, channel: channel) {
        scenePickingMarkEntityDirty(entityId)
    }
}

public func shouldRenderSceneChannelsAsWireframe(_ channels: SceneChannel) -> Bool {
    getSceneChannelRenderMode(channels) == .wireframe
}

public func shouldRenderSceneChannelsOpaque(_ channels: SceneChannel) -> Bool {
    switch getSceneChannelRenderMode(channels) {
    case .normal, .passthroughGhost:
        return true
    case .hidden, .wireframe:
        return false
    }
}

public func passthroughGhostOpacity(for channels: SceneChannel) -> Float? {
    switch getSceneChannelRenderMode(channels) {
    case let .passthroughGhost(opacity):
        return opacity
    case .normal, .hidden, .wireframe:
        return nil
    }
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

private func refreshStaticBatchingForSceneChannelChange(entityId: EntityID) {
    guard BatchingSystem.shared.isEnabled(),
          scene.get(component: StaticBatchComponent.self, for: entityId) != nil
    else {
        return
    }
    BatchingSystem.shared.notifyEntitySceneChannelsChanged(entityId: entityId)
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
