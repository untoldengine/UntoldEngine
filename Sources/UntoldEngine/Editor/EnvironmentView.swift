//
//  EnvironmentView.swift
//
//
//  Created by Harold Serrano on 3/19/25.
//

import simd
import SwiftUI

func addIBL() {
    guard let url = openFilePicker() else { return }

    let filename = url.lastPathComponent

    let directoryURL = url.deletingLastPathComponent()

    generateHDR(filename, from: directoryURL)
}

@available(macOS 12.0, *)
struct EnvironmentView: View {
    @State private var enableApplyIBL: Bool = false
    @State private var enableRenderEnvironment: Bool = false
    @State private var intensity: Float = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environment Settings")
                .font(.headline)
                .padding(.bottom, 8)

            // Add IBL
            Button(action: {
                addIBL()
            }) {
                HStack {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                    Text("Add IBL")
                }
                .padding(6)
                .background(Color.blue)
                .cornerRadius(6.0)
            }
            .buttonStyle(PlainButtonStyle())

            Toggle("Apply IBL", isOn: $enableApplyIBL)
                .onChange(of: enableApplyIBL) { newValue in
                    applyIBL = newValue
                }

            Toggle("Render Environment", isOn: $enableRenderEnvironment)
                .onChange(of: enableRenderEnvironment) { newValue in
                    renderEnvironment = newValue
                }

            TextInputNumberView(label: "Ambient Intensity", value: Binding(
                get: { intensity },
                set: { newIntensity in
                    ambientIntensity = newIntensity
                    intensity = newIntensity
                }))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            enableApplyIBL = applyIBL
            enableRenderEnvironment = renderEnvironment
            intensity = ambientIntensity
        }
    }
}
