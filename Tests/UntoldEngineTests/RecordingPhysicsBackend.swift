//
//  RecordingPhysicsBackend.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine

final class RecordingPhysicsBackend: PhysicsBackend, @unchecked Sendable {
    let id: String
    let capabilities: PhysicsCapabilities = []

    private(set) var configurations: [PhysicsWorldConfiguration] = []
    private(set) var addedBodies: [(entity: EntityID, descriptor: PhysicsBodyDescriptor)] = []
    private(set) var removedBodies: [EntityID] = []
    private(set) var stepDeltas: [Float] = []
    private(set) var kinematicWrites: [[(entity: EntityID, transform: PhysicsBodyTransform)]] = []
    private(set) var drainCount = 0
    private(set) var callOrder: [String] = []

    /// Transforms handed back on the next `readActiveTransforms`.
    var pendingReadback: [(entity: EntityID, transform: PhysicsBodyTransform)] = []
    var droppedEventsToReport = 0

    init(id: String = "com.example.recordingphysics") {
        self.id = id
    }

    func configure(_ config: PhysicsWorldConfiguration) {
        configurations.append(config)
        callOrder.append("configure")
    }

    func didAddBody(entity: EntityID, descriptor: PhysicsBodyDescriptor) {
        addedBodies.append((entity, descriptor))
        callOrder.append("addBody")
    }

    func didRemoveBody(entity: EntityID) {
        removedBodies.append(entity)
        callOrder.append("removeBody")
    }

    func step(deltaTime: Float) {
        stepDeltas.append(deltaTime)
        callOrder.append("step")
    }

    func drainEvents(into sink: any PhysicsEventSink) {
        drainCount += 1
        callOrder.append("drain")
        if droppedEventsToReport > 0 {
            sink.reportDroppedEvents(count: droppedEventsToReport)
        }
    }

    func writeKinematicTargets(_ batch: PhysicsBodyWriteBatch) {
        var entries: [(EntityID, PhysicsBodyTransform)] = []
        for index in 0 ..< batch.entities.count {
            entries.append((batch.entities[index], batch.transforms[index]))
        }
        kinematicWrites.append(entries)
        callOrder.append("writeKinematic")
    }

    func readActiveTransforms(into batch: PhysicsTransformReadBatch) -> Int {
        callOrder.append("read")
        let count = min(pendingReadback.count, batch.capacity)
        for index in 0 ..< count {
            batch.entities[index] = pendingReadback[index].entity
            batch.transforms[index] = pendingReadback[index].transform
        }
        return count
    }
}

struct RecordingBackendPlugin: PhysicsBackendPlugin {
    let manifest: PhysicsBackendPluginManifest
    let backend: RecordingPhysicsBackend

    init(pluginID: String = "com.example.recordingphysics") {
        manifest = PhysicsBackendPluginManifest(
            id: pluginID,
            displayName: "Recording Physics",
            version: PhysicsBackendVersion(major: 1, minor: 0, patch: 0),
            requiredAPIVersion: .current
        )
        backend = RecordingPhysicsBackend(id: pluginID)
    }

    func makeBackend() -> any PhysicsBackend {
        backend
    }
}
