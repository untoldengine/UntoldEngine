#if canImport(AppKit)
import MetalKit
import SwiftUI

public struct Asset: Identifiable {
    public let id = UUID()
    public let name: String
    public let category: String
    public let path: URL
    var isFolder: Bool = false
}

public struct EditorView: View {
    var mtkView: MTKView

    @State private var editor_entities: [EntityID] = getAllGameEntities()
    @StateObject private var selectionManager = SelectionManager()
    @StateObject private var sceneGraphModel = SceneGraphModel()
    @State private var assets: [String: [Asset]] = [:]
    @State private var selectedAsset: Asset? = nil
    @State private var isPlaying = false
    @State private var showAssetBrowser = false

    public init(mtkView: MTKView) {
        self.mtkView = mtkView
        let sharedSelectionManager = SelectionManager()
        _selectionManager = StateObject(wrappedValue: sharedSelectionManager)
        editorController = EditorController(selectionManager: sharedSelectionManager)
    }

    public var body: some View {
        VStack {
            ToolbarView(
                selectionManager: selectionManager, onSave: editor_handleSave,
                onLoad: editor_handleLoad, onClear: editor_clearScene, onCameraSave: editor_cameraSave,
                onPlayToggled: { isPlaying in editor_handlePlayToggle(isPlaying) },
                dirLightCreate: editor_createDirLight,
                pointLightCreate: editor_createPointLight,
                spotLightCreate: editor_createSpotLight,
                areaLightCreate: editor_createAreaLight
            )
            Divider()
            HStack {
                VStack {
                    SceneHierarchyView(selectionManager: selectionManager, sceneGraphModel: sceneGraphModel, entityList: editor_entities, onAddEntity_Editor: editor_addNewEntity, onRemoveEntity_Editor: editor_removeEntity)
                }

                VStack {
                    SceneView(mtkView: mtkView) // Scene placeholder (Metal integration later)
                    TransformManipulationToolbar(controller: editorController!, showAssetBrowser: $showAssetBrowser)
                    if showAssetBrowser {
                        TabView {
                            AssetBrowserView(
                                assets: $assets,
                                selectedAsset: $selectedAsset,
                                selectionManager: selectionManager,
                                editor_addEntityWithAsset: editor_addEntityWithAsset
                            )
                            .tabItem { Label("Assets", systemImage: "shippingbox") }

                            LogConsoleView()
                                .tabItem { Label("Console", systemImage: "terminal") }
                        }
                        .frame(height: 200)
                        .clipped()
                    }
                }

                TabView {
                    EnvironmentView(selectedAsset: $selectedAsset)
                        .tabItem {
                            Label("Environment", systemImage: "sun.max")
                        }

                    PostProcessingEditorView()
                        .tabItem {
                            Label("Effects", systemImage: "cube")
                        }

                    InspectorView(selectionManager: selectionManager, sceneGraphModel: sceneGraphModel, onAddName_Editor: editor_addName, selectedAsset: $selectedAsset)
                        .tabItem {
                            Label("Inspector", systemImage: "cube")
                        }
                }
                .frame(minWidth: 200, maxWidth: 250)
            }
        }
        .background(
            Color.editorBackground.ignoresSafeArea())
        .onAppear {
            sceneGraphModel.refreshHierarchy()
        }
    }

    private func editor_handleSave() {
        let sceneData: SceneData = serializeScene()
        saveScene(sceneData: sceneData)
    }

    private func editor_handleLoad() {
        if let sceneData = loadGameScene() {
            destroyAllEntities()
            EditorComponentsState.shared.clear()
            deserializeScene(sceneData: sceneData)
            editor_entities = getAllGameEntities()
            selectionManager.selectedEntity = nil
            activeEntity = .invalid
            selectionManager.objectWillChange.send()
            sceneGraphModel.refreshHierarchy()
        }
    }

    private func editor_clearScene() {
        destroyAllEntities()
        removeGizmo()
        EditorComponentsState.shared.clear()

        let light = createEntity()
        setEntityName(entityId: light, name: "Directional Light")
        createDirLight(entityId: light)

        let sceneCamera = findSceneCamera()

        resetCameraToDefaultTransform(entityId: sceneCamera)

        let gameCamera = findGameCamera()

        resetCameraToDefaultTransform(entityId: gameCamera)

        editor_entities = getAllGameEntities()
        selectionManager.selectedEntity = nil
        activeEntity = .invalid
        gizmoActive = false
        selectionManager.objectWillChange.send()
        sceneGraphModel.refreshHierarchy()
    }

    private func editor_cameraSave() {
        let sceneCameraEntityID = findSceneCamera()

        if sceneCameraEntityID == .invalid {
            return
        }

        let gameCameraEntityID = findGameCamera()

        if gameCameraEntityID == .invalid {
            return
        }

        let eye = getCameraEye(entityId: sceneCameraEntityID)
        let up = getCameraUp(entityId: sceneCameraEntityID)
        let target = getCameraTarget(entityId: sceneCameraEntityID)

        cameraLookAt(entityId: gameCameraEntityID, eye: eye, target: target, up: up)
    }

    private func editor_loadUSDScene() {
        guard let url = openFilePicker() else { return }

        let filename = url.deletingPathExtension().lastPathComponent
        let withExtension = url.pathExtension

        loadScene(filename: filename, withExtension: withExtension)
        editor_entities = getAllGameEntities()
        selectionManager.selectedEntity = nil
        activeEntity = .invalid
        selectionManager.objectWillChange.send()
    }

    private func editor_addNewEntity() {
        removeGizmo()

        let entityId = createEntity()

        let name = generateEntityName()
        setEntityName(entityId: entityId, name: name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)

        selectionManager.selectedEntity = entityId
        editor_entities = getAllGameEntities()
        sceneGraphModel.refreshHierarchy()
    }

    private func editor_removeEntity() {
        guard let entityId = selectionManager.selectedEntity else {
            print("No entity is selected.") // Handle case where no entity is selected
            return
        }

        destroyEntity(entityId: entityId)

        editor_entities = getAllGameEntities()
        activeEntity = .invalid
        selectionManager.selectedEntity = nil
        removeGizmo()
        sceneGraphModel.refreshHierarchy()
    }

    private func editor_addName() {
        guard let entity = selectionManager.selectedEntity else {
            print("No entity is selected.") // Handle case where no entity is selected
            return
        }

        setEntityName(entityId: entity, name: getEntityName(entityId: entity))
    }

    private func editor_handlePlayToggle(_ isPlaying: Bool) {
        self.isPlaying = isPlaying
        gameMode = !gameMode
    }

    private func editor_createDirLight() {
        let entityId = createEntity()

        let name = generateEntityName()
        setEntityName(entityId: entityId, name: name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)

        createDirLight(entityId: entityId)
        editor_entities = getAllGameEntities()
        sceneGraphModel.refreshHierarchy()
    }

    private func editor_createPointLight() {
        let entityId = createEntity()

        let name = generateEntityName()
        setEntityName(entityId: entityId, name: name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)

        createPointLight(entityId: entityId)
        editor_entities = getAllGameEntities()
        sceneGraphModel.refreshHierarchy()
    }

    private func editor_createSpotLight() {
        let entityId = createEntity()

        let name = generateEntityName()
        setEntityName(entityId: entityId, name: name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)

        createSpotLight(entityId: entityId)
        editor_entities = getAllGameEntities()
        sceneGraphModel.refreshHierarchy()
    }

    private func editor_createAreaLight() {
        let entityId = createEntity()

        let name = generateEntityName()
        setEntityName(entityId: entityId, name: name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)

        createAreaLight(entityId: entityId)
        editor_entities = getAllGameEntities()
        sceneGraphModel.refreshHierarchy()
    }

    private func editor_addEntityWithAsset() {
        editor_addNewEntity()

        let filename = selectedAsset?.path.deletingPathExtension().lastPathComponent
        let withExtension = selectedAsset?.path.pathExtension
        setEntityMesh(entityId: selectionManager.selectedEntity!, filename: filename!, withExtension: withExtension!)

        let mainCamera = getMainCamera()

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: mainCamera) else {
            handleError(.noActiveCamera)
            return
        }

        var forward = forwardDirectionVector(from: cameraComponent.rotation)

        forward *= -1.0

        let camPosition = cameraComponent.localPosition

        let spawnPosition = camPosition + forward * spawnDistance

        translateTo(entityId: selectionManager.selectedEntity!, position: spawnPosition)
    }
}
#endif
