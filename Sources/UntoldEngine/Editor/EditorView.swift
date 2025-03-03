import MetalKit
import SwiftUI

struct Asset: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let path: URL
}

@available(macOS 13.0, *)
public struct EditorView: View {
    var mtkView: MTKView

    @State private var editor_entities: [EntityID] = scene.getAllEntities()
    @StateObject private var selectionManager = SelectionManager()
    @State private var assets: [String: [Asset]] = [:]
    @State private var isPlaying = false

    public init(mtkView: MTKView) {
        self.mtkView = mtkView
    }

    public var body: some View {
        VStack {
            ToolbarView(
                onSave: editor_handleSave,
                onLoad: editor_handleLoad,
                onPlayToggled: { isPlaying in editor_handlePlayToggle(isPlaying) }
            )
            Divider()
            HStack {
                VStack {
                    SceneHierarchyView(selectionManager: selectionManager, entityList: editor_entities, onAddEntity_Editor: editor_addNewEntity, onRemoveEntity_Editor: editor_removeEntity)
                        .frame(minWidth: 250, maxWidth: 250)

                    CameraView()
                        .frame(minWidth: 250, maxWidth: 250)
//                    AssetBrowserView(assets: $assets)
//                        .frame(minWidth: 250, maxWidth: 250)
                }

                SceneView(mtkView: mtkView) // Scene placeholder (Metal integration later)
                InspectorView(selectionManager: selectionManager, onAddName_Editor: editor_addName)
            }
        }
        .background(Color(red: 40.0 / 255, green: 44.0 / 255, blue: 52.0 / 255, opacity: 0.5))
    }

    private func editor_handleSave() {
        print("Saving Scene...")
    }

    private func editor_handleLoad() {
        print("Loading Scene...")
    }

    private func editor_addNewEntity() {
        let entityId = createEntity()

        let name = "Entity \(scene.getAllEntities().count)"
        setEntityName(entityId: entityId, name: name)
        editor_entities = scene.getAllEntities()
    }

    private func editor_removeEntity() {
        guard let entityId = selectionManager.selectedEntity else {
            print("No entity is selected.") // Handle case where no entity is selected
            return
        }

        destroyEntity(entityId: entityId)
        editor_entities = scene.getAllEntities()
    }

    private func editor_addName() {
        guard let entity = selectionManager.selectedEntity else {
            print("No entity is selected.") // Handle case where no entity is selected
            return
        }

        setEntityName(entityId: entity, name: getEntityName(entityId: entity) ?? "No name")
    }

    private func editor_handlePlayToggle(_ isPlaying: Bool) {
        print(isPlaying ? "Entering Play Mode..." : "Stopping Play Mode...")
        self.isPlaying = isPlaying
        gameMode = !gameMode
    }
}
