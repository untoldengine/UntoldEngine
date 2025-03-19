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
    @State private var isIBLEnabled: Bool = true
    @State private var isShowEnvironment: Bool = false
    @State private var intensity: Float = ambientIntensity

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

            Toggle("Enable IBL", isOn: $isIBLEnabled)
                .onChange(of: isIBLEnabled) { newValue in
                    applyIBL = newValue
                }

            Toggle("Show IBL Environment", isOn: $isShowEnvironment)
                .onChange(of: isShowEnvironment) { newValue in
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
    }
}
