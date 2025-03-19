//
//  InspectorView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import simd
import SwiftUI

@available(macOS 13.0, *)
public struct ComponentOption_Editor: Identifiable {
    public let id: Int
    public let name: String
    public let type: Any.Type
    public let view: (EntityID?, @escaping () -> Void) -> AnyView

    public init(id: Int, name: String, type: Any.Type, view: @escaping (EntityID?, @escaping () -> Void) -> AnyView) {
        self.id = id
        self.name = name
        self.type = type
        self.view = view
    }
}

func openFilePicker() -> URL? {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    return panel.runModal() == .OK ? panel.urls.first : nil
}

@available(macOS 13.0, *)
private func onAddMesh_Editor(entityId: EntityID) {
    guard let url = openFilePicker() else { return }

    let filename = url.deletingPathExtension().lastPathComponent
    let withExtension = url.pathExtension

    setEntityMesh(entityId: entityId, filename: filename, withExtension: withExtension)

    guard let inEditorComponent = scene.get(component: InEditorComponent.self, for: entityId) else {
        handleError(.noInEditorComponent)
        return
    }

    inEditorComponent.meshFilename = url
}

private func onAddAnimation_Editor(entityId: EntityID) {
    guard let url = openFilePicker() else { return }

    let filename = url.deletingPathExtension().lastPathComponent
    let withExtension = url.pathExtension

    setEntityAnimations(entityId: entityId, filename: filename, withExtension: withExtension, name: filename)
    changeAnimation(entityId: entityId, name: filename)

    guard let inEditorComponent = scene.get(component: InEditorComponent.self, for: entityId) else {
        handleError(.noInEditorComponent)
        return
    }

    inEditorComponent.animationsFilenames.append(url)
}

@available(macOS 13.0, *)
public func addComponent_Editor(componentOption: ComponentOption_Editor) {
    availableComponents_Editor.append(componentOption)
}

@available(macOS 13.0, *)
var availableComponents_Editor: [ComponentOption_Editor] = [
    ComponentOption_Editor(id: getComponentId(for: RenderComponent.self), name: "Render Component", type: RenderComponent.self, view: { selectedId, refreshView in
        AnyView(
            VStack {
                if let entityId = selectedId {
                    Text("Rendering")

                    HStack {
                        Button(action: {
                            onAddMesh_Editor(entityId: entityId)
                            refreshView()
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                Text("Add Mesh")
                            }

                        }.buttonStyle(PlainButtonStyle())
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: LocalTransformComponent.self), name: "Transform Component", type: LocalTransformComponent.self, view: { selectedEntityId, refreshView in
        AnyView(
            VStack {
                Text("Transform Properties")
                if let entityId = selectedEntityId {
                    let inEditorComponent = scene.get(component: InEditorComponent.self, for: entityId)
                    var orientation = inEditorComponent?.orientation
                    var position = inEditorComponent?.position

                    TextInputVectorView(label: "Position", value: Binding(
                        get: { position! },
                        set: { newPosition in
                            translateTo(entityId: entityId, position: newPosition)
                            inEditorComponent?.position = newPosition
                            refreshView()
                        }))

                    TextInputVectorView(label: "Orientation", value: Binding(
                        get: { orientation! },
                        set: { newOrientation in
                            rotateTo(entityId: entityId, pitch: newOrientation.x, yaw: newOrientation.y, roll: newOrientation.z)
                            inEditorComponent?.orientation = newOrientation
                            refreshView()
                        }))
                }
            } // end vstack
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: AnimationComponent.self), name: "Animation Component", type: AnimationComponent.self, view: { selectedId, refreshView in
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
                }

                // Add animation UI
                HStack {
                    Button(action: {
                        onAddAnimation_Editor(entityId: selectedId!)
                        refreshView()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                            Text("Add Animation")
                        }

                    }.buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        )
    }),
    ComponentOption_Editor(id: getComponentId(for: KineticComponent.self), name: "Kinetic Component", type: KineticComponent.self, view: { selectedId, refreshView in
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
    ComponentOption_Editor(id: getComponentId(for: LightComponent.self), name: "Light Component", type: LightComponent.self, view: { selectedId, refreshView in
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
    ComponentOption_Editor(id: getComponentId(for: CameraComponent.self), name: "Camera Component", type: CameraComponent.self, view: { selectedId, refreshView in
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

@available(macOS 13.0, *)
func mergeEntityComponents(
    selectedEntity: EntityID?,
    editor_entityComponents: [EntityID: [ObjectIdentifier: ComponentOption_Editor]],
    editor_availableComponents: [ComponentOption_Editor]
) -> [ObjectIdentifier: ComponentOption_Editor] {
    guard let entityId = selectedEntity else { return [:] }

    var mergedComponents = editor_entityComponents[entityId] ?? [:]

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

@available(macOS 13.0, *)
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

@available(macOS 13.0, *)
struct InspectorView: View {
    @ObservedObject var selectionManager: SelectionManager
    var onAddName_Editor: () -> Void
    @State private var showComponentSelection = false
    @State private var editor_entityComponents: [EntityID: [ObjectIdentifier: ComponentOption_Editor]] = [:]
    @FocusState private var isNameTextFieldFocused: Bool

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
                                editor_entityComponents: editor_entityComponents,
                                editor_availableComponents: availableComponents_Editor
                            )

                            let sortedComponents = sortEntityComponents(componentOption_Editor: mergedComponents)

                            ForEach(sortedComponents, id: \.id) { editor_component in
                                editor_component.view(entityId, refreshView)
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
            .background(Color.black.opacity(0.1))
        }
    }

    func addComponentToEntity_Editor(componentType: Any.Type) {
        guard let entityId = selectionManager.selectedEntity else { return }

        let key = ObjectIdentifier(componentType)

        if let component = availableComponents_Editor.first(where: { ObjectIdentifier($0.type) == key }) {
            // Ensure the entity has an entry in the dictionary
            if editor_entityComponents[entityId] == nil {
                editor_entityComponents[entityId] = [:]
            }

            // Add component to the entity-specific dictionary
            editor_entityComponents[entityId]?[key] = component

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
    }
}
