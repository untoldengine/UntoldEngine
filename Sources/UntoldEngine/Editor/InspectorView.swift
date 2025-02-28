//
//  InspectorView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import simd
import SwiftUI

@available(macOS 12.0, *)
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

func openFilePicker() -> String? {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    return panel.runModal() == .OK ? panel.urls.first?.deletingPathExtension().lastPathComponent : nil
}

@available(macOS 12.0, *)
private func onAddMesh_Editor(entityId: EntityID) {
    guard let url = openFilePicker() else { return }

    setEntityMesh(entityId: entityId, filename: url, withExtension: "usdc")
}

private func onAddAnimation_Editor(entityId: EntityID) {
    guard let url = openFilePicker() else { return }

    setEntityAnimations(entityId: entityId, filename: url, withExtension: "usdc", name: url)
    changeAnimation(entityId: entityId, name: url)
}

private func onAddKinetics_Editor(entityId: EntityID) {
    setEntityKinetics(entityId: entityId)
}

@available(macOS 12.0, *)
public func addComponent_Editor(componentOption: ComponentOption_Editor) {
    availableComponents_Editor.append(componentOption)
}

@available(macOS 12.0, *)
var availableComponents_Editor: [ComponentOption_Editor] = [
    ComponentOption_Editor(id: getComponentId(for: RenderComponent.self), name: "Render Component", type: RenderComponent.self, view: { selectedId, _ in
        AnyView(
            VStack {
                if let entityId = selectedId {
                    Text("Rendering")

                    HStack {
                        Button(action: {
                            onAddMesh_Editor(entityId: entityId)
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
                Text("Transform")
                if let entityId = selectedEntityId {
                    let position = getLocalPosition(entityId: entityId)
                    let orientationEuler = getLocalOrientationEuler(entityId: entityId)
                    let orientationVector = simd_float3(orientationEuler.pitch, orientationEuler.yaw, orientationEuler.roll)

                    TransformInputView(label: "Position", transform: Binding(
                        get: { position },
                        set: { newPosition in
                            translateTo(entityId: entityId, position: newPosition)
                            refreshView()
                        }))

                    TransformInputView(label: "Orientation", transform: Binding(
                        get: { orientationVector },
                        set: { newOrientation in
                            rotateTo(entityId: entityId, pitch: newOrientation.x, yaw: newOrientation.y, roll: newOrientation.z)
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
                    Text("Animation")
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
                    Button(action: {
                        onAddKinetics_Editor(entityId: entityId)
                        refreshView()
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                            Text("Add Properties")
                        }

                    }.buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if hasComponent(entityId: entityId, componentType: KineticComponent.self) {
                        let mass = getMass(entityId: entityId)
                        NumberInputView(label: "Mass", transform: Binding(
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
]

@available(macOS 12.0, *)
struct InspectorView: View {
    @ObservedObject var selectionManager: SelectionManager
    var onAddName_Editor: () -> Void
    @State private var showComponentSelection = false
    @State private var editor_entityComponents: [EntityID: [ObjectIdentifier: ComponentOption_Editor]] = [:]

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
                            .onSubmit {
                                onAddName_Editor()
                                refreshView()
                            }
                        }

                        Divider()

                        if let editor_components = editor_entityComponents[entityId] {
                            let sortedComponents = Array(editor_components.values).sorted { lhs, rhs in
                                let order: [String: Int] = [
                                    "Render Component": 1,
                                    "Transform Component": 2,
                                    "Animation Component": 3,
                                    "Kinetic Component": 4,
                                ]
                                return (order[lhs.name] ?? Int.max) < (order[rhs.name] ?? Int.max)
                            }

                            ForEach(sortedComponents, id: \.id) { editor_component in
                                editor_component.view(entityId, refreshView)
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity) // Ensure ScrollView takes available space
            } else {
                Text("No entity selected")
                    .foregroundColor(.gray)
            }

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
        }
        .frame(minWidth: 200, maxWidth: 250)
        .background(Color.black.opacity(0.05))
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

                Button("Cancel") {
                    showComponentSelection = false
                }
                .padding()
            }
            .frame(width: 300, height: 300)
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
        }
    }

    private func refreshView() {
        selectionManager.objectWillChange.send()
    }
}
