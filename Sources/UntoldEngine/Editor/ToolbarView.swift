//
//  ToolbarView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import SwiftUI

@available(macOS 12.0, *)
struct ToolbarView: View {
    var onSave: () -> Void
    var onLoad: () -> Void
    var onPlayToggled: (Bool) -> Void // Now tracks Play Mode

    @State private var isPlaying = false // 🔄 Track Play Mode

    var body: some View {
        HStack(spacing: 10) {
            ToolbarButton(iconName: "folder.fill.badge.plus", action: onLoad, tooltip: "Load Scene")
            ToolbarButton(iconName: "square.and.arrow.down.fill", action: onSave, tooltip: "Save Scene")

            if #available(macOS 11.0, *) {
                Button(action: {
                    isPlaying.toggle()
                    onPlayToggled(isPlaying) // 🔄 Notify Play Mode change
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.title2)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                        .shadow(radius: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .help(isPlaying ? "Stop Scene" : "Play Scene")
            } else {
                // Fallback on earlier versions
            } // Tooltip updates dynamically
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4) // ⬇️ Reduce toolbar height
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

@available(macOS 12.0, *)
struct ToolbarButton: View {
    let iconName: String
    let action: () -> Void
    let tooltip: String

    var body: some View {
        if #available(macOS 11.0, *) {
            Button(action: action) {
                Image(systemName: iconName)
                    .font(.title2)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
                    .shadow(radius: 2)
            }
            .buttonStyle(PlainButtonStyle()) // Removes default button styling
            .help(tooltip)
        } else {
            // Fallback on earlier versions
        } // Shows tooltip when hovering
    }
}
