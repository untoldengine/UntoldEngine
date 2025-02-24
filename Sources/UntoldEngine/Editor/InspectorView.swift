//
//  InspectorView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import simd
import SwiftUI

@available(macOS 12.0, *)
struct InspectorView: View {
    @ObservedObject var selectionManager: SelectionManager
    let assets: [String: [Asset]]
    var onAddMesh: () -> Void
    var onAddName: () -> Void
    var onAddAnimation: () -> Void
    @State private var selectedAnimation: String? = nil // selected animation to add
    @State private var selectedMesh: String? = nil
    @State private var hasKinetics: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Inspector")
                .font(.headline)

            Divider()

            Text("Mesh")

            if let entityId = selectionManager.selectedEntity {
                HStack {
                    Text("Name")
                    TextField("Set Entity Name", text: Binding(
                        get: { getEntityName(entityId: entityId) ?? "No name" },
                        set: {
                            setEntityName(entityId: entityId, name: $0)
                            selectionManager.objectWillChange.send()
                        }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onSubmit {
                        onAddName()
                    }
                }

                if !hasComponent(entityId: entityId, componentType: RenderComponent.self) {
                    HStack {
                        Button(action: {
                            onAddMesh()
                            selectionManager.hasMesh.toggle()
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

                if hasComponent(entityId: entityId, componentType: RenderComponent.self) {
                    // Transforms section
                    Divider()

                    Text("Transforms")

                    let position = getLocalPosition(entityId: entityId)
                    let orientationEuler = getLocalOrientationEuler(entityId: entityId)
                    let orientationVector = simd_float3(orientationEuler.pitch, orientationEuler.yaw, orientationEuler.roll)

                    TransformInputView(label: "Position", transform: Binding(
                        get: { position },
                        set: { newPosition in
                            translateTo(entityId: entityId, position: newPosition)
                            selectionManager.objectWillChange.send()
                        }))

                    TransformInputView(label: "Orientation", transform: Binding(
                        get: { orientationVector },
                        set: { newOrientation in
                            rotateTo(entityId: entityId, pitch: newOrientation.x, yaw: newOrientation.y, roll: newOrientation.z)
                            selectionManager.objectWillChange.send()
                        }))

                    Divider()

                    // Animation section
                    Text("Animations")
                    VStack {
                        // List of currently linked animations
                        if hasComponent(entityId: entityId, componentType: AnimationComponent.self) {
                            let animationClips: [String] = getAllAnimationClips(entityId: entityId)

                            List {
                                ForEach(animationClips, id: \.self) { animation in

                                    HStack {
                                        Text(animation) // Display animation name
                                        Spacer()
                                        Button(action: {
                                            removeAnimationClip(entityId: entityId, animationClip: animation)
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
                                onAddAnimation()
                                selectionManager.objectWillChange.send()
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
                    .padding()

                    Divider()

                    Text("Physics")

                    Toggle(isOn: $hasKinetics) {
                        Text("Enable Kinetics")
                    }
                    .toggleStyle(.checkbox)
                    .padding()
                    .onChange(of: hasKinetics) { newValue in
                        if newValue == true {
                            setEntityKinetics(entityId: entityId)
                        } else {
                            removeEntityKinetics(entityId: entityId)
                        }
                    }
                }

            } else {
                Text("No entity selected")
                    .foregroundColor(.gray)
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
        .background(Color.black.opacity(0.05))
        .padding()
    }
}
