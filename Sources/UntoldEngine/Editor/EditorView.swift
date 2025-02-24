import MetalKit
import SwiftUI

struct Asset: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let path: URL
}

@available(macOS 12.0, *)
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
                    SceneHierarchyView(selectionManager: selectionManager, entityList: editor_entities, onAddEntity: editor_addNewEntity, onRemoveEntity: editor_removeEntity)
                        .frame(minWidth: 250, maxWidth: 250)

//                    AssetBrowserView(assets: $assets)
//                        .frame(minWidth: 250, maxWidth: 250)
                }

                SceneView(mtkView: mtkView) // Scene placeholder (Metal integration later)
                InspectorView(selectionManager: selectionManager, assets: assets, onAddMesh: editor_addNewMesh, onAddName: editor_addName, onAddAnimation: editor_addAnimation)
            }
        }
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

    private func editor_addNewMesh() {
        guard let url = editor_openFilePicker() else { return }

        guard let entityId = selectionManager.selectedEntity else {
            print("No entity is selected.") // Handle case where no entity is selected
            return
        }
        setEntityMesh(entityId: entityId, filename: url, withExtension: "usdc")
    }

    private func editor_addAnimation() {
        guard let url = editor_openFilePicker() else { return }

        guard let entityId = selectionManager.selectedEntity else {
            print("No entity is selected.") // Handle case where no entity is selected
            return
        }

        setEntityAnimations(entityId: entityId, filename: url, withExtension: "usdc", name: url)
        changeAnimation(entityId: entityId, name: url)
    }

    private func editor_handlePlayToggle(_ isPlaying: Bool) {
        print(isPlaying ? "Entering Play Mode..." : "Stopping Play Mode...")
        self.isPlaying = isPlaying
        gameMode = !gameMode
    }

    func editor_openFilePicker() -> String? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        return panel.runModal() == .OK ? panel.urls.first?.deletingPathExtension().lastPathComponent : nil
    }
}
