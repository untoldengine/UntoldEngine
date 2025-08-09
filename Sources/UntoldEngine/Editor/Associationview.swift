//
//  AssociationView.swift
//
//
//  Created by Harold Serrano on 8/9/25.
//

import Foundation
import SwiftUI

struct AssociationSelection: Equatable {
    var linkEmissive = false
    // Add more in the future:
    // var linkFollowTransform = false
    // var linkShadowCaster = false
}

struct AssociationDialog: View {
    let entityA: EntityID
    let entityB: EntityID
    let onConfirm: (AssociationSelection) -> Void
    let onCancel: () -> Void

    @State private var selection = AssociationSelection()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with names
            HStack {
                VStack(alignment: .leading) {
                    Text("Linking: \(getEntityName(entityId: entityA) ?? "Entity") to \(getEntityName(entityId: entityB) ?? "Entity")")
                        .font(.headline)
                }
                Spacer()
            }

            Divider()

            // Checkboxes (only Emissive for now)
            Toggle("Link emissive color", isOn: $selection.linkEmissive)
                .disabled(!isValidEmissivePair(entityA, entityB))
                .help("Links light temperature/RGB to mesh emissive")

            // Future options:
            // Toggle("Follow transform", isOn: $selection.linkFollowTransform)

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Apply") {
                    onConfirm(selection)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(
            Color.editorBackground.ignoresSafeArea()
        )
        .onAppear {
            // Pre-fill defaults based on current state
            selection.linkEmissive = currentEmissiveLink(entityA, entityB)
        }
    }

    // MARK: - Validation hooks
    func isValidEmissivePair(_ entityA: EntityID, _ entityB: EntityID) -> Bool {
        // Allow (light, mesh) or (mesh, light) in any order
        let e1IsLight = hasComponent(entityId: entityA, componentType: SpotLightComponent.self)
                      || hasComponent(entityId: entityA, componentType: PointLightComponent.self)
                      || hasComponent(entityId: entityA, componentType: AreaLightComponent.self)
        let e2IsLight = hasComponent(entityId: entityB, componentType: SpotLightComponent.self)
                      || hasComponent(entityId: entityB, componentType: PointLightComponent.self)
                      || hasComponent(entityId: entityB, componentType: AreaLightComponent.self)

        let e1IsMesh = hasComponent(entityId: entityA, componentType: RenderComponent.self)
        let e2IsMesh = hasComponent(entityId: entityB, componentType: RenderComponent.self)

        return (e1IsLight && e2IsMesh) || (e2IsLight && e1IsMesh)
    }

    func currentEmissiveLink(_ entityA: EntityID, _ entityB: EntityID) -> Bool {
        // Return true if the light already links to this mesh
        if let light = [entityA, entityB].first(where: { hasComponent(entityId: $0, componentType: SpotLightComponent.self)
                                            || hasComponent(entityId: $0, componentType: PointLightComponent.self)
                                            || hasComponent(entityId: $0, componentType: AreaLightComponent.self) }),
           let mesh  = [entityA, entityB].first(where: { $0 != light && hasComponent(entityId: $0, componentType: RenderComponent.self) }),
            let link = scene.get(component: LightEmissiveMeshLinkComponent.self, for: light){
            
            return link.meshEntity == mesh
        }
        return false
    }
}
