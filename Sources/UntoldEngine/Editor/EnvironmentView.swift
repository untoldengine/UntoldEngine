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
                .background(Color.gray)
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


struct ColorGradingEditorView: View {
    @ObservedObject var settings = ColorGradingParams.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Grading").font(.headline)
            
            Text("Exposure")
            Slider(value: $settings.exposure, in: -5.0 ... 5.0)
            Text(String(format: "%.2f", settings.exposure))

            Text("Brightness")
            Slider(value: $settings.brightness, in: -1.0 ... 1.0)
            Text(String(format: "%.2f", settings.brightness))

            Text("Contrast")
            Slider(value: $settings.contrast, in: -5.0 ... 5.0)
            Text(String(format: "%.2f", settings.contrast))

            Text("Saturation")
            Slider(value: $settings.saturation, in: 0.0 ... 5.0)
            Text(String(format: "%.2f", settings.saturation))
        }
        .padding()
    }
}

struct WhiteBalanceEditorView: View {
    @ObservedObject var settings = ColorGradingParams.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("White Balance").font(.headline)

            Text("Temperature")
            Slider(value: $settings.temperature, in: -100.0 ... 100.0)
            Text(String(format: "%.2f", settings.temperature))

            Text("Tint")
            Slider(value: $settings.tint, in: -100.0 ... 100.0)
            Text(String(format: "%.2f", settings.tint))

//            TextInputVectorView(label: "Lift", value: Binding(
//                get: { settings.lift },
//                set: { newLift in
//                    settings.lift = newLift
//                }))
//
//            TextInputVectorView(label: "Gamma", value: Binding(
//                get: { settings.gamma },
//                set: { newGamma in
//                    settings.gamma = newGamma
//                }))
//
//            TextInputVectorView(label: "Gain", value: Binding(
//                get: { settings.gain },
//                set: { newGain in
//                    settings.gain = newGain
//                }))
        }
        .padding()
    }
}

struct BloomEditorView: View {
    @ObservedObject var settings = BloomThresholdParams.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bloom").font(.headline)

            Text("Threshold")
            Slider(value: $settings.threshold, in: 0.0 ... 5.0)
            Text(String(format: "%.2f", settings.threshold))

            Text("Intensity")
            Slider(value: $settings.intensity, in: 0.0 ... 100.0)
            Text(String(format: "%.2f", settings.intensity))

        }
        .padding()
    }
}

struct VignetteEditorView: View {
    @ObservedObject var settings = VignetteParams.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vignette").font(.headline)

            Text("Intensity")
            Slider(value: $settings.intensity, in: 0.0 ... 1.0)
            Text(String(format: "%.2f", settings.intensity))

            Text("Radius")
            Slider(value: $settings.radius, in: 0.0 ... 1.0)
            Text(String(format: "%.2f", settings.radius))

            Text("Softness")
            Slider(value: $settings.softness, in: 0.0 ... 1.0)
            Text(String(format: "%.2f", settings.softness))
            
//            TextInputVectorView(label: "Center", value: Binding(
//                get: { settings.center },
//                set: { newCenter in
//                    settings.center = newCenter
//                }))

        }
        .padding()
    }
}

struct ChromaticAberrationEditorView: View {
    @ObservedObject var settings = ChromaticAberrationParams.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chromatic Aberration").font(.headline)

            Text("Intensity")
            Slider(value: $settings.intensity, in: 0.0 ... 0.01)
            Text(String(format: "%.4f", settings.intensity))

//            TextInputVectorView(label: "Center", value: Binding(
//                get: { settings.center },
//                set: { newCenter in
//                    settings.center = newCenter
//                }))

        }
        .padding()
    }
}

struct DepthOfFieldEditorView: View {
    @ObservedObject var settings = DepthOfFieldParams.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Depth of Field").font(.headline)

            Text("Focus Distance")
            Slider(value: $settings.focusDistance, in: 0.0 ... 10.0)
            Text(String(format: "%.2f", settings.focusDistance))

            Text("Focus Range")
            Slider(value: $settings.focusRange, in: 0.0 ... 10.0)
            Text(String(format: "%.4f", settings.focusRange))

            Text("Max Blur")
            Slider(value: $settings.maxBlur, in: 0.0 ... 0.05)
            Text(String(format: "%.4f", settings.maxBlur))

        }
        .padding()
    }
}

struct SSAOEditorView: View {
    @ObservedObject var settings = SSAOParams.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SSAO").font(.headline)

            Text("Radius")
            Slider(value: $settings.radius, in: 0.0 ... 2.0)
            Text(String(format: "%.2f", settings.radius))

            Text("Bias")
            Slider(value: $settings.bias, in: 0.0 ... 0.1)
            Text(String(format: "%.4f", settings.bias))

            Text("Intensity")
            Slider(value: $settings.intensity, in: 0.0 ... 2.0)
            Text(String(format: "%.2f", settings.intensity))

        }
        .padding()
    }
}

struct PostProcessingEditorView: View {
    @State private var showToneMapping = false
    @State private var showWhiteBalance = false
    @State private var showColorGrading = false
    @State private var showBloom = false
    @State private var showVignette = false
    @State private var showChromatic = false
    @State private var showDoF = false
    @State private var showSSAO = false
    @State private var showDebugPostProccessTexture = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                DisclosureGroup("Depth of Field", isExpanded: $showDoF){
                    DepthOfFieldEditorView()
                }
                
                DisclosureGroup("Chromatic Aberration", isExpanded: $showChromatic){
                    ChromaticAberrationEditorView()
                }
                
                DisclosureGroup("Bloom", isExpanded: $showBloom) {
                    BloomEditorView()
                }
                
                DisclosureGroup("Color Grading", isExpanded: $showColorGrading) {
                    ColorGradingEditorView()
                }
                
                DisclosureGroup("WhiteBalance", isExpanded: $showWhiteBalance) {
                    WhiteBalanceEditorView()
                }

                DisclosureGroup("Vignette", isExpanded: $showVignette){
                    VignetteEditorView()
                }
                
  
//                DisclosureGroup("SSAO", isExpanded: $showSSAO){
//                    SSAOEditorView()
//                }
//                
                DisclosureGroup("Debug", isExpanded: $showDebugPostProccessTexture) {
                    DebuggerEditorView()
                }
            }
            .padding()
        }
    }
}


struct DebuggerEditorView: View {
    @ObservedObject var settings = DebugSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debugger ").font(.headline)

            Picker("Debug Texture", selection: $settings.selectedName) {
                ForEach(DebugTextureRegistry.allNames(), id: \.self) { name in
                    Text(name)
                }
            }
        }
        .padding()
    }
}
