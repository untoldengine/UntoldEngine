//
//  ToolbarView.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//
#if canImport(AppKit)
import SwiftUI

struct ToolbarView: View {
    @ObservedObject var selectionManager: SelectionManager

    var onSave: () -> Void
    var onLoad: () -> Void
    var onClear: () -> Void
    var onCameraSave: () -> Void
    var onPlayToggled: (Bool) -> Void
    var dirLightCreate: () -> Void
    var pointLightCreate: () -> Void
    var spotLightCreate: () -> Void
    var areaLightCreate: () -> Void

    @State private var isPlaying = false

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                ToolbarButton(iconName: "clear.fill", action: onClear, tooltip: "Clear Scene")
            }

            Spacer() // Push content to the center

            // Centered Buttons
            HStack(spacing: 12) {
                ToolbarButton(iconName: "square.and.arrow.down", action: onLoad, tooltip: "Import JSON Scene")

                Button(action: {
                    isPlaying.toggle()
                    onPlayToggled(isPlaying)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(isPlaying ? "Pause" : "Play")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(isPlaying ? Color.red : Color.blue)
                    .cornerRadius(6)
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(PlainButtonStyle())
                .help(isPlaying ? "Pause Scene" : "Play Scene")

                ToolbarButton(iconName: "square.and.arrow.up", action: onSave, tooltip: "Export JSON Scene")
                ToolbarButton(iconName: "camera.fill", action: onCameraSave, tooltip: "Save Camera Transform")
            }

            Spacer()

            // Right-aligned Light Buttons
            HStack(spacing: 12) {
                ToolbarButton(iconName: "sun.horizon", action: dirLightCreate, tooltip: "Directional Light")
                ToolbarButton(iconName: "lightbulb.fill", action: pointLightCreate, tooltip: "Point Light")
                ToolbarButton(iconName: "lamp.ceiling", action: spotLightCreate, tooltip: "Spot Light")
                ToolbarButton(iconName: "light.panel.fill", action: areaLightCreate, tooltip: "Area Light")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(
            Color.secondary.opacity(0.1)
                .ignoresSafeArea()
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Toolbar Button Component

struct ToolbarButton: View {
    let iconName: String
    let action: () -> Void
    let tooltip: String

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.gray)
                .cornerRadius(6)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
    }
}
#endif
