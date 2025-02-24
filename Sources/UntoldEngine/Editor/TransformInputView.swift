//
//  TransformInputView.swift
//
//
//  Created by Harold Serrano on 2/23/25.
//

import simd
import SwiftUI

@available(macOS 12.0, *)
struct TransformInputView: View {
    let label: String
    @Binding var transform: SIMD3<Float>
    @State private var tempValues: [String] = ["0", "0", "0"]

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.headline)

            HStack {
                ForEach(0 ..< 3, id: \.self) { index in
                    TextField("", text: Binding(
                        get: { tempValues[index] },
                        set: { tempValues[index] = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .onChange(of: transform[index]) { newValue in
                        tempValues[index] = String(newValue) // Update when entity changes
                    }
                    .onSubmit {
                        if let newValue = Float(tempValues[index]) {
                            transform[index] = newValue
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            tempValues = [String(transform.x), String(transform.y), String(transform.z)] // Convert explicitly
        }
    }
}
