//
//  CameraView.swift
//
//
//  Created by Harold Serrano on 2/27/25.
//

import simd
import SwiftUI

@available(macOS 12.0, *)
struct CameraView: View {
    @State private var position: simd_float3 = .zero
    @State private var orientation: simd_float3 = .zero

    var body: some View {
        VStack(alignment: .leading) {
            Divider()
            Text("Camera")
                .font(.headline)

            TextInputVectorView(label: "Position", value: Binding(
                get: { position },
                set: { newPosition in
                    camera.translateTo(newPosition.x, newPosition.y, newPosition.z)
                }))

            TextInputVectorView(label: "Orientation", value: Binding(
                get: { orientation },
                set: { newOrientation in
                    camera.rotateCamera(pitch: newOrientation.x, yaw: newOrientation.y)
                }))
        }
        .padding(10)
        .background(Color.black.opacity(0.05))
        .cornerRadius(5)
        .padding(.bottom, 10)
        .onAppear {
            startUpdating()
        }
        .background(Color(red: 40.0 / 255, green: 44.0 / 255, blue: 52.0 / 255, opacity: 0.5))
    }

    private func startUpdating() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            let newPosition = camera.getPosition()
            let newOrientation = transformQuaternionToEulerAngles(q: camera.rotation)

            position = newPosition
            orientation = simd_float3(newOrientation.pitch, newOrientation.yaw, newOrientation.roll)
        }
    }
}
