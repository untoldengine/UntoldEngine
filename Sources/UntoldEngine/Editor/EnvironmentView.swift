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
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Header

            HStack(spacing: 6) {
                Image(systemName: "leaf.arrow.triangle.circlepath")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14)) // Smaller icon
                Text("Environment Settings")
                    .font(.headline) // Smaller title
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 6)

            Divider()

            // MARK: - Add IBL Button (Compact)

            Button(action: {
                addIBL()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 12)) // Smaller icon
                    Text("Add IBL")
                        .font(.system(size: 12))
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())

            Divider()

            // MARK: - IBL and Environment Toggles (Compact)

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $enableApplyIBL) {
                    Label("Apply IBL", systemImage: enableApplyIBL ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                }
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.85) // Make toggle smaller
                .onChange(of: enableApplyIBL) { newValue in
                    applyIBL = newValue
                }

                Toggle(isOn: $enableRenderEnvironment) {
                    Label("Render Environment", systemImage: enableRenderEnvironment ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                }
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.85)
                .onChange(of: enableRenderEnvironment) { newValue in
                    renderEnvironment = newValue
                }
            }

            Divider()

            // MARK: - Ambient Intensity Slider (Compact)

            VStack(alignment: .leading, spacing: 4) {
                Text("Ambient Intensity")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                TextInputNumberView(label: "Intensity", value: Binding(
                    get: { intensity },
                    set: { newIntensity in
                        ambientIntensity = newIntensity
                        intensity = newIntensity
                    }
                ))
                .frame(maxWidth: 80) // Make the input field smaller
            }
        }
        .padding(8) // Reduce padding
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        .onAppear {
            enableApplyIBL = applyIBL
            enableRenderEnvironment = renderEnvironment
            intensity = ambientIntensity
        }
    }
}
