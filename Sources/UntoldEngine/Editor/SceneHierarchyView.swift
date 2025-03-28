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
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Header with Add/Remove Buttons

            HStack {
                Image(systemName: "diagram.tree")
                    .foregroundColor(.accentColor)
                Text("Scene Graph")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                // Add Entity Button
                Button(action: onAddEntity_Editor) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add Entity")

                // Remove Entity Button
                Button(action: onRemoveEntity_Editor) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 18))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Remove Selected Entity")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            // MARK: - Entity List

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entityList, id: \.self) { entityId in
                        EntityRow(
                            entityID: entityId,
                            entityName: getEntityName(entityId: entityId) ?? "No Name",
                            isSelected: entityId == selectionManager.selectedEntity
                        )
                        .contentShape(Rectangle()) // Full row is clickable
                        .onTapGesture {
                            selectionManager.selectEntity(entityId: entityId)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .scrollContentBackground(.hidden)
            .frame(maxHeight: 300)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)

            Spacer() // Pushes content to the top
        }
        .frame(minWidth: 200, maxWidth: 250)
        .padding(8)
        .background(Color.editorBackground.ignoresSafeArea())
        .cornerRadius(12)
    }
}

// MARK: - Entity Row

@available(macOS 13.0, *)
struct EntityRow: View {
    let entityID: EntityID
    let entityName: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cube.fill")
                .foregroundColor(isSelected ? .white : .gray)

            Text(entityName)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.8) : Color.clear)
        .cornerRadius(6)
    }
}
