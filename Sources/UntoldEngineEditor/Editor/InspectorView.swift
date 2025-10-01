//
//  InspectorView.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//
import simd
import SwiftUI
import UntoldEngine

public struct ComponentOption_Editor: Identifiable {
    public let id: Int
    public let name: String
    public let type: Any.Type
    public let view: (EntityID?, Asset?, @escaping () -> Void) -> AnyView
    public let onAdd: ((EntityID) -> Void)?

    public init(id: Int, name: String, type: Any.Type, view: @escaping (EntityID?, Asset?, @escaping () -> Void) -> AnyView, onAdd: ((EntityID) -> Void)? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.view = view
        self.onAdd = onAdd
    }
}

func openFilePicker() -> URL? {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    return panel.runModal() == .OK ? panel.urls.first : nil
}

private func onAddMesh_Editor(entityId: EntityID, url: URL) {
    let filename = url.deletingPathExtension().lastPathComponent
    let withExtension = url.pathExtension

    setEntityMesh(entityId: entityId, filename: filename, withExtension: withExtension)
}

private func onAddAnimation_Editor(entityId: EntityID, url: URL) {
    let filename = url.deletingPathExtension().lastPathComponent
    let withExtension = url.pathExtension

    setEntityAnimations(entityId: entityId, filename: filename, withExtension: withExtension, name: filename)
    // changeAnimation(entityId: entityId, name: filename)

    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    animationComponent.animationsFilenames.append(url)
}

public func addComponent_Editor(componentOption: ComponentOption_Editor) {
    availableComponents_Editor.append(componentOption)
}

var availableComponents_Editor: [ComponentOption_Editor] = [
    ComponentOption_Editor(id: getComponentId(for: RenderComponent.self), name: "Render Component", type: RenderComponent.self, view: { selectedId, asset, refreshView in
        AnyView(
            Group {
                if let entityId = selectedId {
                    RenderingEditorView(entityId: entityId, asset: asset, refreshView: refreshView)
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: LocalTransformComponent.self), name: "Transform Component", type: LocalTransformComponent.self, view: { selectedEntityId, _, refreshView in
        AnyView(
            Group {
                if let entityId = selectedEntityId {
                    TransformationEditorView(entityId: entityId, refreshView: refreshView)
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: AnimationComponent.self), name: "Animation Component", type: AnimationComponent.self, view: { selectedId, asset, refreshView in
        AnyView(
            Group {
                if let entityId = selectedId {
                    AnimationEditorView(entityId: entityId, asset: asset, refreshView: refreshView)
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: KineticComponent.self), name: "Kinetic Component", type: KineticComponent.self, view: { selectedId, _, refreshView in
        AnyView(
            Group {
                if let entityId = selectedId {
                    KineticEditorView(entityId: entityId, refreshView: refreshView)
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: DirectionalLightComponent.self), name: "Dir Light Component", type: DirectionalLightComponent.self, view: { selectedId, _, refreshView in
        AnyView(
            Group {
                if let entityId = selectedId {
                    DirLightEditorView(entityId: entityId, refreshView: refreshView)
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: PointLightComponent.self), name: "Point Light Component", type: PointLightComponent.self, view: { selectedId, _, refreshView in
        AnyView(
            Group {
                if let entityId = selectedId {
                    PointLightEditorView(entityId: entityId, refreshView: refreshView)
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: SpotLightComponent.self), name: "Spot Light Component", type: SpotLightComponent.self, view: { selectedId, _, refreshView in
        AnyView(
            Group {
                if let entityId = selectedId {
                    SpotLightEditorView(entityId: entityId, refreshView: refreshView)
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: AreaLightComponent.self), name: "Area Light Component", type: AreaLightComponent.self, view: { selectedId, _, refreshView in
        AnyView(
            Group {
                if let entityId = selectedId {
                    AreaLightEditorView(entityId: entityId, refreshView: refreshView)
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: CameraComponent.self), name: "Camera Component", type: CameraComponent.self, view: { selectedId, _, refreshView in
        AnyView(
            Group {
                if let entityId = selectedId {
                    CameraEditorView(entityId: entityId, refreshView: refreshView)
                }
            }
        )
    }),
]

func mergeEntityComponents(
    selectedEntity: EntityID?,
    editor_availableComponents: [ComponentOption_Editor]
) -> [ObjectIdentifier: ComponentOption_Editor] {
    guard let entityId = selectedEntity else { return [:] }

    var mergedComponents = EditorComponentsState.shared.components[entityId] ?? [:]

    let existingComponentIDs: [Int] = getAllEntityComponentsIds(entityId: entityId)

    let matchingComponents = editor_availableComponents.filter { existingComponentIDs.contains($0.id) }

    for match in matchingComponents {
        let key = ObjectIdentifier(match.type)

        if mergedComponents[key] == nil {
            mergedComponents[key] = match
        }
    }

    return mergedComponents
}

func sortEntityComponents(componentOption_Editor: [ObjectIdentifier: ComponentOption_Editor]) -> [ComponentOption_Editor] {
    let sortedComponents = Array(componentOption_Editor.values).sorted { lhs, rhs in
        let order: [String: Int] = [
            "Render Component": 1,
            "Transform Component": 2,
            "Animation Component": 3,
            "Kinetic Component": 4,
        ]
        return (order[lhs.name] ?? Int.max) < (order[rhs.name] ?? Int.max)
    }

    return sortedComponents
}

struct InspectorView: View {
    @ObservedObject var selectionManager: SelectionManager
    @ObservedObject var sceneGraphModel: SceneGraphModel
    @ObservedObject var editorComponentsState = EditorComponentsState.shared
    var onAddName_Editor: () -> Void
    @State private var showComponentSelection = false
    // @State private var editor_entityComponents: [EntityID: [ObjectIdentifier: ComponentOption_Editor]] = [:]
    @FocusState private var isNameTextFieldFocused: Bool
    @Binding var selectedAsset: Asset?

    var body: some View {
        VStack(alignment: .leading) {
            Text("Inspector")
                .font(.headline)

            if let entityId = selectionManager.selectedEntity, entityId != .invalid {
                ScrollView { // Make the entire inspector scrollable
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Name")
                            TextField("Set Entity Name", text: Binding(
                                get: { getEntityName(entityId: entityId) },
                                set: {
                                    setEntityName(entityId: entityId, name: $0)
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                            .focused($isNameTextFieldFocused)
                            .onSubmit {
                                onAddName_Editor()
                                refreshView()
                                isNameTextFieldFocused = false
                            }
                        }

                        if let entityId = selectionManager.selectedEntity {
                            let mergedComponents = mergeEntityComponents(
                                selectedEntity: entityId,
                                editor_availableComponents: availableComponents_Editor
                            )

                            let sortedComponents = sortEntityComponents(componentOption_Editor: mergedComponents)

                            ForEach(sortedComponents, id: \.id) { editor_component in
                                editor_component.view(entityId, selectedAsset, refreshView)
                                    .frame(minWidth: 200, maxWidth: 250)
                                Divider()
                            }
                        } else {
                            Text("No entity selected").foregroundColor(.gray)
                        }
                    }
                }
                .frame(maxHeight: .infinity) // Ensure ScrollView takes available space

                Button(action: { showComponentSelection = true }) {
                    HStack {
                        Image(systemName: "Plus")
                            .foregroundColor(.white)
                        Text("Add Components")
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            } else {
                Text("No entity selected")
                    .foregroundColor(.gray)
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
        .padding()
        .sheet(isPresented: $showComponentSelection) {
            VStack {
                Text("Select a Component")
                    .font(.headline)
                    .padding()

                List(availableComponents_Editor, id: \.id) { component in
                    Button(action: {
                        addComponentToEntity_Editor(componentType: component.type)
                        showComponentSelection = false
                    }) {
                        HStack {
                            Image(systemName: "cube")
                            Text(component.name)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .scrollContentBackground(.hidden) // Hides system background

                Button("Cancel") {
                    showComponentSelection = false
                }
                .padding()
            }
            .frame(width: 300, height: 300)
            .background(
                Color.editorBackground.ignoresSafeArea()
            )
        }
    }

    func addComponentToEntity_Editor(componentType: Any.Type) {
        guard let entityId = selectionManager.selectedEntity else { return }

        let key = ObjectIdentifier(componentType)

        if let component = availableComponents_Editor.first(where: { ObjectIdentifier($0.type) == key }) {
            // Ensure the entity has an entry in the dictionary
            if editorComponentsState.components[entityId] == nil {
                editorComponentsState.components[entityId] = [:]
            }

            // Add component to the entity-specific dictionary
            editorComponentsState.components[entityId]?[key] = component

            component.onAdd?(entityId)

            if key == ObjectIdentifier(DirectionalLightComponent.self) {
                createDirLight(entityId: entityId)
            } else if key == ObjectIdentifier(PointLightComponent.self) {
                createPointLight(entityId: entityId)
            } else if key == ObjectIdentifier(SpotLightComponent.self) {
                createSpotLight(entityId: entityId)
            } else if key == ObjectIdentifier(AreaLightComponent.self) {
                createAreaLight(entityId: entityId)
            } else if key == ObjectIdentifier(KineticComponent.self) {
                setEntityKinetics(entityId: entityId)
            } else if key == ObjectIdentifier(CameraComponent.self) {
                createGameCamera(entityId: entityId)
            }
        }
    }

    private func refreshView() {
        selectionManager.objectWillChange.send()
        sceneGraphModel.refreshHierarchy()
    }
}

/*
 struct TemplateEditorView: View{
 let entityId: EntityID
 let asset: Asset?
 let refreshView: () -> Void

 var body: some View{

 }
 }
 */

struct RenderingEditorView: View {
    let entityId: EntityID
    let asset: Asset?
    let refreshView: () -> Void

    var body: some View {
        Text("Mesh")

        HStack(spacing: 12) {
            Text(getAssetURLString(entityId: entityId) ?? " ")
            Button(action: {
                let selectedCategory: AssetCategory = .models
                if let assetPath = asset?.path, selectedCategory.rawValue == asset?.category {
                    onAddMesh_Editor(entityId: entityId, url: assetPath)
                }
                refreshView()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.white)
                    Text("Assign")
                        .fontWeight(.regular)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)

        if hasComponent(entityId: entityId, componentType: RenderComponent.self), hasComponent(entityId: entityId, componentType: LightComponent.self) == false {
            Text("Material Properties")
                .font(.headline)
                .padding(.bottom, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 24) {
                    ForEach(TextureType.allCases) { type in

                        let image: NSImage? = {
                            if let url = getMaterialTextureURL(entityId: entityId, type: type),
                               let img = NSImage(contentsOf: url)
                            {
                                return img
                            } else {
                                return NSImage(named: "Default Texture")
                            }
                        }()

                        VStack(alignment: .center, spacing: 8) {
                            // Texture preview
                            Button(action: {
                                if asset?.category == "Materials", let path = asset?.path {
                                    updateMaterialTexture(entityId: entityId, textureType: type, path: path)
                                    refreshView()
                                }
                            }) {
                                if let image {
                                    Image(nsImage: image)
                                        .resizable()
                                        .frame(width: 64, height: 64)
                                        .cornerRadius(6)
                                } else {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .frame(width: 64, height: 64)
                                        .foregroundColor(.gray)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Remove texture
                            Button(action: {
                                removeMaterialTexture(entityId: entityId, textureType: type)
                                refreshView()
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())

                            // Texture name
                            Text(type.displayName)
                                .font(.caption)
                                .padding(.top, 4)

                            Divider().padding(.vertical, 4)

                            // Wrap Mode
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wrap Mode")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Picker("", selection: bindingForWrapMode(entityId: entityId, textureType: type, onChange: refreshView)) {
                                    ForEach(WrapMode.allCases) { mode in
                                        Text(mode.description).tag(mode)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: 100)
                            }
                        }
                        .frame(width: 100) // lock column width for consistency
                    }
                }
                .padding(.horizontal, 12)
            }

            HStack {
                Text("UV Scale")
                    .font(.callout)
                    .foregroundColor(.secondary)

                TextInputNumberView(
                    label: "",
                    value: Binding(
                        get: { getMaterialSTScale(entityId: entityId) },
                        set: { newValue in
                            updateMaterialSTScale(entityId: entityId, stScale: newValue)
                            refreshView()
                        }
                    )
                )
                .frame(width: 60)
            }

            Divider()
            HStack {
                // Base Color Picker
                VStack {
                    ColorPicker("", selection: Binding(
                        get: { colorFromSimd(getMaterialBaseColor(entityId: entityId)) },
                        set: { newColor in updateMaterialColor(entityId: entityId, color: newColor) }
                    ))
                    .frame(width: 60)

                    Text("Base Color")
                        .font(.caption)
                    // .foregroundColor(.secondary)
                }

                // Roughness Input
                VStack {
                    TextInputNumberView(
                        label: "",
                        value: Binding(
                            get: { getMaterialRoughness(entityId: entityId) },
                            set: { newValue in
                                updateMaterialRoughness(entityId: entityId, roughness: newValue)
                                refreshView()
                            }
                        )
                    )
                    .frame(width: 60)

                    Text("Roughness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Metallic Input
                VStack {
                    TextInputNumberView(
                        label: "",
                        value: Binding(
                            get: { getMaterialMetallic(entityId: entityId) },
                            set: { newValue in
                                updateMaterialMetallic(entityId: entityId, metallic: newValue)
                                refreshView()
                            }
                        )
                    )
                    .frame(width: 60)

                    Text("Metallic")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Emmissive Input
            VStack {
                TextInputVectorView(
                    label: "",
                    value: Binding(
                        get: { getMaterialEmmissive(entityId: entityId) },
                        set: { newValue in
                            updateMaterialEmmisive(entityId: entityId, emmissive: newValue)
                            refreshView()
                        }
                    )
                )
                .frame(width: 80)

                Text("Emmisive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TransformationEditorView: View {
    let entityId: EntityID
    let refreshView: () -> Void

    var body: some View {
        Text("Transform Properties")
        let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)
        let position = getLocalPosition(entityId: entityId)
        let orientation = simd_float3(localTransformComponent!.rotationX, localTransformComponent!.rotationY, localTransformComponent!.rotationZ)
        let scale = getScale(entityId: entityId)
        TextInputVectorView(label: "Position", value: Binding(
            get: { position },
            set: { newPosition in
                translateTo(entityId: entityId, position: newPosition)
                refreshView()
            }))

        TextInputVectorView(label: "Orientation", value: Binding(
            get: { orientation },
            set: { newOrientation in
                applyAxisRotations(entityId: entityId, axis: newOrientation)
                refreshView()
            }))

        TextInputVectorView(label: "Scale", value: Binding(
            get: { scale },
            set: { newScale in
                scaleTo(entityId: entityId, scale: newScale)
                refreshView()
            }))
    }
}

struct AnimationEditorView: View {
    let entityId: EntityID
    let asset: Asset?
    let refreshView: () -> Void

    var body: some View {
        Text("Animation Properties")
        // List of currently linked animations
        let animationClips: [String] = getAllAnimationClips(entityId: entityId)

        List {
            ForEach(animationClips, id: \.self) { animation in

                HStack {
                    Text(animation) // Display animation name
                    Spacer()
                    Button(action: {
                        removeAnimationClip(entityId: entityId, animationClip: animation)
                        refreshView()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .frame(height: 100)
        .scrollContentBackground(.hidden) // Hide default background
        .background(Color.gray.opacity(0.3)) // Apply a dark background
        .cornerRadius(8) // Optional: Add corner radius for a sleek look
        // Add animation UI
        HStack {
            Button(action: {
                let selectedCategory: AssetCategory = .animations
                if let assetPath = asset?.path, selectedCategory.rawValue == asset?.category {
                    onAddAnimation_Editor(entityId: entityId, url: assetPath)
                }
                refreshView()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.white)
                    Text("Assign")
                        .fontWeight(.regular)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct KineticEditorView: View {
    let entityId: EntityID
    let refreshView: () -> Void

    var body: some View {
        Text("Kinetic System")

        if hasComponent(entityId: entityId, componentType: KineticComponent.self) {
            let mass = getMass(entityId: entityId)
            TextInputNumberView(label: "Mass", value: Binding(
                get: { mass },
                set: { newMass in
                    setMass(entityId: entityId, mass: newMass)
                    refreshView()
                }))
        }
    }
}

struct DirLightEditorView: View {
    let entityId: EntityID
    let refreshView: () -> Void

    var body: some View {
        Text("Light Property")

        if hasComponent(entityId: entityId, componentType: DirectionalLightComponent.self) {
            VStack {
                let color: simd_float3 = getLightColor(entityId: entityId)
                let intensity: Float = getLightIntensity(entityId: entityId)

                TextInputVectorView(label: "Color", value: Binding(
                    get: { color },
                    set: { newColor in
                        updateLightColor(entityId: entityId, color: newColor)
                        refreshView()

                    }))
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextInputNumberView(label: "Intensity", value: Binding(
                    get: { intensity },
                    set: { newIntensity in
                        updateLightIntensity(entityId: entityId, intensity: newIntensity)
                        refreshView()
                    }))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct PointLightEditorView: View {
    let entityId: EntityID
    let refreshView: () -> Void

    var body: some View {
        Text("Light Property")

        if hasComponent(entityId: entityId, componentType: PointLightComponent.self) {
            VStack {
                let color: simd_float3 = getLightColor(entityId: entityId)
                let intensity: Float = getLightIntensity(entityId: entityId)
                let falloff: Float = getLightFalloff(entityId: entityId)
                let radius: Float = getLightRadius(entityId: entityId)

                TextInputVectorView(label: "Color", value: Binding(
                    get: { color },
                    set: { newColor in
                        updateLightColor(entityId: entityId, color: newColor)
                        refreshView()

                    }))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    TextInputNumberView(label: "Brighness", value: Binding(
                        get: { intensity },
                        set: { newIntensity in
                            updateLightIntensity(entityId: entityId, intensity: newIntensity)
                            refreshView()
                        }))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextInputNumberView(label: "Falloff", value: Binding(
                        get: { falloff },
                        set: { newFalloff in
                            updateLightFalloff(entityId: entityId, falloff: newFalloff)
                            refreshView()
                        }))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextInputNumberView(label: "Radius", value: Binding(
                        get: { radius },
                        set: { newRadius in
                            updateLightRadius(entityId: entityId, radius: newRadius)
                            refreshView()
                        }))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct SpotLightEditorView: View {
    let entityId: EntityID
    let refreshView: () -> Void

    var body: some View {
        Text("Light Property")

        if hasComponent(entityId: entityId, componentType: SpotLightComponent.self) {
            VStack {
                let color: simd_float3 = getLightColor(entityId: entityId)
                let falloff: Float = getLightFalloff(entityId: entityId)
                let intensity: Float = getLightIntensity(entityId: entityId)
                let coneAngle: Float = getLightConeAngle(entityId: entityId)
                TextInputVectorView(label: "Color", value: Binding(
                    get: { color },
                    set: { newColor in
                        updateLightColor(entityId: entityId, color: newColor)
                        refreshView()

                    }))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    TextInputNumberView(label: "Brightness", value: Binding(
                        get: { intensity },
                        set: { newIntensity in
                            updateLightIntensity(entityId: entityId, intensity: newIntensity)
                            refreshView()
                        }))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextInputNumberView(label: "Falloff", value: Binding(
                        get: { falloff },
                        set: { newFalloff in
                            updateLightFalloff(entityId: entityId, falloff: newFalloff)
                            refreshView()
                        }))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextInputNumberView(label: "Cone Angle", value: Binding(
                        get: { coneAngle },
                        set: { newConeAngle in
                            updateLightConeAngle(entityId: entityId, coneAngle: newConeAngle)
                            refreshView()
                        }))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct AreaLightEditorView: View {
    let entityId: EntityID
    let refreshView: () -> Void

    var body: some View {
        Text("Light Property")

        if hasComponent(entityId: entityId, componentType: AreaLightComponent.self) {
            VStack {
                let color: simd_float3 = getLightColor(entityId: entityId)
                let intensity: Float = getLightIntensity(entityId: entityId)
                // add area lights properties here
                TextInputVectorView(label: "Color", value: Binding(
                    get: { color },
                    set: { newColor in
                        updateLightColor(entityId: entityId, color: newColor)
                        refreshView()

                    }))
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextInputNumberView(label: "Brightness", value: Binding(
                    get: { intensity },
                    set: { newIntensity in
                        updateLightIntensity(entityId: entityId, intensity: newIntensity)
                        refreshView()
                    }))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct CameraEditorView: View {
    let entityId: EntityID
    let refreshView: () -> Void

    var body: some View {
        Text("Camera System")

        if hasComponent(entityId: entityId, componentType: CameraComponent.self) {
            let eye: simd_float3 = getCameraEye(entityId: entityId)
            let up: simd_float3 = getCameraUp(entityId: entityId)
            let target: simd_float3 = getCameraTarget(entityId: entityId)

            TextInputVectorView(label: "Eye", value: Binding(
                get: { eye },
                set: { newEye in
                    cameraLookAt(entityId: findGameCamera(), eye: newEye, target: target, up: up)
                    refreshView()
                }))

            TextInputVectorView(label: "Up", value: Binding(
                get: { up },
                set: { newUp in
                    cameraLookAt(entityId: findGameCamera(), eye: eye, target: target, up: newUp)
                    refreshView()
                }))

            TextInputVectorView(label: "Target", value: Binding(
                get: { target },
                set: { newTarget in
                    cameraLookAt(entityId: findGameCamera(), eye: eye, target: newTarget, up: up)
                    refreshView()
                }))
        }
    }
}
