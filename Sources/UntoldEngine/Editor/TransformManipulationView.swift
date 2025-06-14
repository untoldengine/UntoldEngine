//
//  TransformManipulationView.swift
//
//
//  Created by Harold Serrano on 4/18/25.
//

import Foundation
import SwiftUI

struct ModeButton: View {
    let icon: String
    let label: String
    let mode: TransformManipulationMode
    @Binding var activeMode: TransformManipulationMode

    var isActive: Bool {
        activeMode == mode
    }

    var body: some View {
        Button(action: {
           
            if gizmoActive == false{
                return
            }
            
            if activeMode == mode {
                activeMode = .none
            } else {
                activeMode = mode
               
                if activeMode == .translate{
                    createGizmo(name:"translateGizmo")
                }else if activeMode == .rotate{
                    createGizmo(name:"rotateGizmo")
                }else if activeMode == .scale{
                    createGizmo(name: "scaleGizmo")
                }
            }
        }) {
            HStack {
                Image(systemName: icon)
                // Text(label)
            }
            .padding(8)
            .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TransformManipulationToolbar: View {
    @ObservedObject var controller: EditorController

    var body: some View {
        HStack(spacing: 5) {
            ModeButton(
                icon: "arrow.up.and.down.and.arrow.left.and.right",
                label: "Translate",
                mode: .translate,
                activeMode: $controller.activeMode
            )
            ModeButton(
                icon: "rotate.3d",
                label: "Rotate",
                mode: .rotate,
                activeMode: $controller.activeMode
            )
            ModeButton(
                icon: "arrow.up.left.and.down.right.magnifyingglass",
                label: "Scale",
                mode: .scale,
                activeMode: $controller.activeMode
            )
        }
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(5)
        .frame(maxWidth: 50)
    }
}
