//
//  ToolbarView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import SwiftUI

@available(macOS 13.0, *)
struct ToolbarView: View {
    @ObservedObject var selectionManager: SelectionManager
    var onSave: () -> Void
    var onLoad: () -> Void
    var onOpenUSDScene: () -> Void
    var onPlayToggled: (Bool) -> Void // Now tracks Play Mode

    @State private var isPlaying = false // 🔄 Track Play Mode

    var body: some View {
        HStack(spacing: 10) {
            ToolbarButton(iconName: "square.and.arrow.down", action: onLoad, tooltip: "Import json Scene")

            ToolbarButton(iconName: "photo.artframe", action: onOpenUSDScene, tooltip: "Load USD Scene")
            Spacer()
            Button(action: {
                isPlaying.toggle()
                onPlayToggled(isPlaying)
            }) {
                Image(systemName: isPlaying ? "pause" : "play")
                    .font(.title2)
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
            .help(isPlaying ? "Stop Scene" : "Play Scene")
            Spacer()
            ToolbarButton(iconName: "square.and.arrow.up", action: onSave, tooltip: "Export json Scene")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8) //
        .background(
            Color.editorBackground.ignoresSafeArea()
        )
    }
}

@available(macOS 13.0, *)
struct ToolbarButton: View {
    let iconName: String
    let action: () -> Void
    let tooltip: String

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.title2)
                .padding(8)
        }
        .buttonStyle(PlainButtonStyle())
        .help(tooltip)
    }
}
