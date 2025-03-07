//
//  SceneHierarchyView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import SwiftUI

@available(macOS 13.0, *)
struct SceneHierarchyView: View {
    @ObservedObject var selectionManager: SelectionManager
    var entityList: [EntityID]
    var onAddEntity_Editor: () -> Void
    var onRemoveEntity_Editor: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Scene Graph")
                .font(.headline)

            List(entityList, id: \.self) { entityId in

                EntityRow(entityID: entityId,
                          entityName: getEntityName(entityId: entityId) ?? "No name",
                          isSelected: entityId == selectionManager.selectedEntity)
                    .contentShape(Rectangle()) // Ensure full row is clickable
                    .onTapGesture {
                        selectionManager.selectEntity(entityId: entityId)
                    }
            }
            .scrollContentBackground(.hidden) // Hides system background

            Spacer() // Pushes the "+" button to the bottom

            HStack {
                // Add Entity Button
                Button(action: onAddEntity_Editor) {
                    HStack {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                        Text("Add Entity")
                    }
                }
                .buttonStyle(PlainButtonStyle()) // Remove default button style
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading) // Align with list items

                // Remove Entity Button

                Button(action: onRemoveEntity_Editor) {
                    HStack {
                        Image(systemName: "minus")
                            .foregroundColor(.white)
                        Text("Remove Entity")
                    }
                }
                .buttonStyle(PlainButtonStyle()) // Remove default button style
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading) // Align with list items
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
        .background(Color.black.opacity(0.05))
    }
}

@available(macOS 13.0, *)
struct EntityRow: View {
    let entityID: EntityID
    let entityName: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(entityName) // show entity name
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .blue : .primary)
        }
        .padding(5)
    }
}
