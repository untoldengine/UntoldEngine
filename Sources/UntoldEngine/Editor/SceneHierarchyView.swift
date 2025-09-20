//
//  SceneHierarchyView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//
#if canImport(AppKit)
import SwiftUI

struct SceneHierarchyView: View {
    @ObservedObject var selectionManager: SelectionManager
    @ObservedObject var sceneGraphModel: SceneGraphModel
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
                    ForEach(sceneGraphModel.getChildren(entityId: nil), id: \.self) { entityId in
                        HierarchyNode(
                            entityId: entityId,
                            entityName: getEntityName(entityId: entityId),
                            depth: 0,
                            sceneGraphModel: sceneGraphModel,
                            selectionManager: selectionManager
                        )
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
        .frame(minWidth: 200, maxWidth: 200)
        .padding(8)
        .background(Color.editorBackground.ignoresSafeArea())
        .cornerRadius(12)
    }
}

// MARK: - Entity Row

struct EntityRow: View {
    let entityid: EntityID
    let entityName: String
    @ObservedObject var selectionManager: SelectionManager

    private var isSelected: Bool {
        entityid == selectionManager.selectedEntity
    }

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
        .background(isSelected ? Color.gray.opacity(0.8) : Color.clear)
        .cornerRadius(6)
    }
}

struct HierarchyNode: View {
    let entityId: EntityID
    let entityName: String
    let depth: Int
    @ObservedObject var sceneGraphModel: SceneGraphModel
    let selectionManager: SelectionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            EntityRow(
                entityid: entityId,
                entityName: entityName,
                selectionManager: selectionManager
            )
            .contentShape(Rectangle())
            .padding(.leading, CGFloat(depth * 12))
            .onTapGesture {
                selectionManager.selectEntity(entityId: entityId)
            }

            // Children
            ForEach(sceneGraphModel.getChildren(entityId: entityId), id: \.self) { childID in
                HierarchyNode(
                    entityId: childID,
                    entityName: getEntityName(entityId: childID),
                    depth: depth + 1,
                    sceneGraphModel: sceneGraphModel,
                    selectionManager: selectionManager
                )
            }
        }
    }
}
#endif
