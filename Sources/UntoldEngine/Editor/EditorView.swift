import MetalKit
import SwiftUI

public struct Asset: Identifiable {
    public let id = UUID()
    public let name: String
    public let category: String
    public let path: URL
}

@available(macOS 13.0, *)
public struct EditorView: View {
    var mtkView: MTKView

    @State private var editor_entities: [EntityID] = getAllGameEntities()
    @StateObject private var selectionManager = SelectionManager()
    @State private var assets: [String: [Asset]] = [:]
    @State private var selectedAsset: Asset? = nil
    @State private var isPlaying = false

    public init(mtkView: MTKView) {
        self.mtkView = mtkView
    }

    public var body: some View {
        VStack {
            ToolbarView(
                selectionManager: selectionManager, onSave: editor_handleSave,
                onLoad: editor_handleLoad,
                onPlayToggled: { isPlaying in editor_handlePlayToggle(isPlaying) }
            )
            Divider()
            HStack {
                VStack {
                    TabView {
                        SceneHierarchyView(selectionManager: selectionManager, entityList: editor_entities, onAddEntity_Editor: editor_addNewEntity, onRemoveEntity_Editor: editor_removeEntity)
                            .tabItem {
                                Label("Scene", systemImage: "cube")
                            }

                        EnvironmentView()
                            .tabItem {
                                Label("Environment", systemImage: "sun.max")
                            }
                    }
                    .frame(minWidth: 200, maxWidth: 200)
                }

                VStack {
                    SceneView(mtkView: mtkView) // Scene placeholder (Metal integration later)

                    AssetBrowserView(assets: $assets, selectedAsset: $selectedAsset)
                }
                InspectorView(selectionManager: selectionManager, onAddName_Editor: editor_addName, selectedAsset: $selectedAsset)
            }
        }
        .background(
            Color.editorBackground.ignoresSafeArea()
        )
    }

    private func editor_handleSave() {
        let sceneData: SceneData = serializeScene()
        saveScene(sceneData: sceneData)
    }

    private func editor_handleLoad() {
        if let sceneData = loadScene() {
            destroyAllEntities()
            deserializeScene(sceneData: sceneData)
            editor_entities = getAllGameEntities()
            selectionManager.selectedEntity = nil
            selectionManager.objectWillChange.send()
        }
    }

    private func editor_loadUSDScene() {
        guard let url = openFilePicker() else { return }

        let filename = url.deletingPathExtension().lastPathComponent
        let withExtension = url.pathExtension

        loadScene(filename: filename, withExtension: withExtension)
        editor_entities = getAllGameEntities()
        selectionManager.selectedEntity = nil
        selectionManager.objectWillChange.send()
    }

    private func editor_addNewEntity() {
        let entityId = createEntity()

        let name = generateEntityName()
        setEntityName(entityId: entityId, name: name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)
        editor_entities = getAllGameEntities()
    }

    private func editor_removeEntity() {
        guard let entityId = selectionManager.selectedEntity else {
            print("No entity is selected.") // Handle case where no entity is selected
            return
        }

        destroyEntity(entityId: entityId)
        editor_entities = getAllGameEntities()
        selectionManager.selectedEntity = nil
    }

    private func editor_addName() {
        guard let entity = selectionManager.selectedEntity else {
            print("No entity is selected.") // Handle case where no entity is selected
            return
        }

        setEntityName(entityId: entity, name: getEntityName(entityId: entity) ?? "No name")
    }

    private func editor_handlePlayToggle(_ isPlaying: Bool) {
        self.isPlaying = isPlaying
        gameMode = !gameMode
    }
}
