//
//  InspectorView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import simd
import SwiftUI

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
            VStack {
                if let entityId = selectedId {
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
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: LocalTransformComponent.self), name: "Transform Component", type: LocalTransformComponent.self, view: { selectedEntityId, _, refreshView in
        AnyView(
            VStack {
                Text("Transform Properties")
                if let entityId = selectedEntityId {
                    let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)
                    var position = getLocalPosition(entityId: entityId)
                    var orientation = simd_float3(localTransformComponent!.rotationX, localTransformComponent!.rotationY, localTransformComponent!.rotationZ)

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
                }
            } // end vstack
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: AnimationComponent.self), name: "Animation Component", type: AnimationComponent.self, view: { selectedId, asset, refreshView in
        AnyView(
            VStack {
                if let entityId = selectedId {
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
                }

                // Add animation UI
                HStack {
                    Button(action: {
                        let selectedCategory: AssetCategory = .animations
                        if let assetPath = asset?.path, selectedCategory.rawValue == asset?.category {
                            onAddAnimation_Editor(entityId: selectedId!, url: assetPath)
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
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: KineticComponent.self), name: "Kinetic Component", type: KineticComponent.self, view: { selectedId, _, refreshView in
        AnyView(
            VStack {
                if let entityId = selectedId {
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
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: LightComponent.self), name: "Light Component", type: LightComponent.self, view: { selectedId, _, refreshView in
        AnyView(
            VStack {
                if let entityId = selectedId {
                    Text("Light Property")

                    if hasComponent(entityId: entityId, componentType: LightComponent.self) {
                        VStack {
                            let color: simd_float3 = getLightColor(entityId: entityId)
                            let attenuation: simd_float3 = getLightAttenuation(entityId: entityId)
                            let intensity: Float = getLightIntensity(entityId: entityId)
                            let radius: Float = getLightRadius(entityId: entityId)

                            let lightTypes = ["directional", "point"]

                            let currentLightType = getLightType(entityId: entityId)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Light Type")
                                    .font(.headline) // optional styling
                                Picker("", selection: Binding(
                                    get: { currentLightType },
                                    set: { newType in
                                        if let lightTypeEnum = LightType(rawValue: newType) {
                                            updateLightType(entityId: entityId, type: lightTypeEnum)
                                            refreshView()
                                        }
                                    }
                                )) {
                                    ForEach(lightTypes, id: \.self) { type in
                                        Text(type.capitalized).tag(type)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            TextInputVectorView(label: "Color", value: Binding(
                                get: { color },
                                set: { newColor in
                                    updateLightColor(entityId: entityId, color: newColor)
                                    refreshView()

                                }))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            TextInputVectorView(label: "Attenuation", value: Binding(
                                get: { getLightAttenuation(entityId: entityId) },
                                set: { newAttenuation in
                                    updateLightAttenuation(entityId: entityId, attenuation: newAttenuation)
                                    refreshView()

                                }))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack {
                                TextInputNumberView(label: "Intensity", value: Binding(
                                    get: { intensity },
                                    set: { newIntensity in
                                        updateLightIntensity(entityId: entityId, intensity: newIntensity)
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
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: CameraComponent.self), name: "Camera Component", type: CameraComponent.self, view: { selectedId, _, refreshView in
        AnyView(
            VStack {
                if let entityId = selectedId {
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

            if let entityId = selectionManager.selectedEntity {
                ScrollView { // Make the entire inspector scrollable
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Name")
                            TextField("Set Entity Name", text: Binding(
                                get: { getEntityName(entityId: entityId) ?? "No name" },
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

                        Divider()
                        if let entityId = selectionManager.selectedEntity {
                            let mergedComponents = mergeEntityComponents(
                                selectedEntity: entityId,
                                editor_availableComponents: availableComponents_Editor
                            )

                            let sortedComponents = sortEntityComponents(componentOption_Editor: mergedComponents)

                            ForEach(sortedComponents, id: \.id) { editor_component in
                                editor_component.view(entityId, selectedAsset, refreshView)
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

            if key == ObjectIdentifier(LightComponent.self) {
                createLight(entityId: entityId, lightType: .directional)

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
