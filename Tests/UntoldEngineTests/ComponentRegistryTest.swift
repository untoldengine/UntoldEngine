//
//  ComponentRegistryTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngine
import XCTest

private final class UnregisteredCleanupComponent: Component {
    required init() {}
}


@MainActor
final class ComponentRegistryTest: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        ensureComponentCleanupHandlersRegistered()
    }

    func testAllComponentTypesInComponentsFileAreRegistered() throws {
        let componentsSource = try String(contentsOf: componentsFileURL(), encoding: .utf8)
        let componentTypeNames = parseComponentTypeNames(from: componentsSource)
        let registeredTypeNames = ComponentRegistry.registeredComponentTypeNames()

        let missing = componentTypeNames.subtracting(registeredTypeNames).sorted()

        XCTAssertTrue(
            missing.isEmpty,
            "Missing cleanup handlers for component types: \(missing.joined(separator: ", "))"
        )
    }

    func testFinalizePendingDestroysExecutesRegistryCleanup() {
        let entityId = createEntity()

        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: PointLightComponent.self)
        registerComponent(entityId: entityId, componentType: LightComponent.self)
        registerComponent(entityId: entityId, componentType: StaticBatchComponent.self)
        registerComponent(entityId: entityId, componentType: LODComponent.self)
        registerComponent(entityId: entityId, componentType: GaussianComponent.self)
        registerComponent(entityId: entityId, componentType: CameraComponent.self)
        registerComponent(entityId: entityId, componentType: SceneCameraComponent.self)
        registerComponent(entityId: entityId, componentType: AssetInstanceComponent.self)
        registerComponent(entityId: entityId, componentType: DerivedAssetNodeComponent.self)
        registerComponent(entityId: entityId, componentType: ScriptComponent.self)
        registerComponent(entityId: entityId, componentType: StreamingComponent.self)
        registerComponent(entityId: entityId, componentType: GizmoComponent.self)
        setEntityName(entityId: entityId, name: "cleanup-test")

        var loadTask: Task<Void, Never>?
        if let streaming = scene.get(component: StreamingComponent.self, for: entityId) {
            let task = Task<Void, Never> {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
            streaming.loadTask = task
            loadTask = task
        }

        destroyEntity(entityId: entityId)
        finalizePendingDestroys()

        let entityIndex = Int(getEntityIndex(entityId))

        XCTAssertTrue(scene.entities[entityIndex].freed, "Entity should be freed after finalize.")
        XCTAssertEqual(scene.entities[entityIndex].mask.bits, 0, "All component bits should be cleared.")
        XCTAssertNil(entityNameMap[entityId], "Entity name should be removed during destroy.")
        XCTAssertTrue(loadTask?.isCancelled ?? false, "Streaming task should be cancelled on destroy.")
    }

    func testUnregisteredComponentIsDetected() {
        XCTAssertFalse(
            ComponentRegistry.hasCleanupHandler(for: UnregisteredCleanupComponent.self),
            "Unregistered test component should not have a cleanup handler."
        )
    }

    private func componentsFileURL(filePath: String = #filePath) -> URL {
        var current = URL(fileURLWithPath: filePath).deletingLastPathComponent()

        while current.path != "/" {
            let package = current.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return current.appendingPathComponent("Sources/UntoldEngine/ECS/Components.swift")
            }
            current.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: "Sources/UntoldEngine/ECS/Components.swift")
    }

    private func parseComponentTypeNames(from source: String) -> Set<String> {
        let pattern = #"public\s+class\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*Component\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(source.startIndex..., in: source)
        let matches = regex.matches(in: source, options: [], range: range)

        var names: Set<String> = []
        names.reserveCapacity(matches.count)

        for match in matches where match.numberOfRanges > 1 {
            guard let nameRange = Range(match.range(at: 1), in: source) else {
                continue
            }
            names.insert(String(source[nameRange]))
        }

        return names
    }
}
