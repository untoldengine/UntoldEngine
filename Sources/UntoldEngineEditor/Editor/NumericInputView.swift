//
//  NumericInputView.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//
#if canImport(AppKit)
    import simd
    import SwiftUI

    /*
     @available(macOS 12.0, *)
     struct NumericInputView<T: Equatable>: View {
         let label: String
         @Binding var value: T
         @State private var tempValues: [String] = []
         @FocusState private var focusedField: Int?

         var body: some View {
             VStack(alignment: .leading) {
                 Text(label)
                     .font(.headline)

                 HStack {
                     ForEach(0 ..< tempValues.count, id: \.self) { index in
                         TextField("", text: Binding(
                             get: { tempValues[index] },
                             set: { tempValues[index] = $0 }
                         ))
                         .textFieldStyle(RoundedBorderTextFieldStyle())
                         .frame(width: 60)
                         .focused($focusedField, equals: index)
                         .onSubmit {
                             applyChanges()
                             focusedField = nil
                         }
                     }
                 }
             }
             .padding(.vertical, 4)
             .onAppear { syncTempValues() }
             .onChange(of: value) { _ in
                 if focusedField == nil { // ✅ Only sync if the user is NOT typing
                     syncTempValues()
                 }
             } // Sync when external value changes
         }

         /// Syncs UI input fields with the bound value
         private func syncTempValues() {
             if let floatValue = value as? Float {
                 tempValues = [String(floatValue)]
             } else if let simdValue = value as? SIMD2<Float> {
                 tempValues = [String(simdValue.x), String(simdValue.y)]
             } else if let simdValue = value as? SIMD3<Float> {
                 tempValues = [String(simdValue.x), String(simdValue.y), String(simdValue.z)]
             }
         }

         /// Applies changes back to the bound value when the user presses Enter
         private func applyChanges() {
             if let floatValue = value as? Float, let newFloat = Float(tempValues[0]) {
                 value = newFloat as! T
             } else if let simdValue = value as? SIMD2<Float>,
                       let x = Float(tempValues[0]),
                       let y = Float(tempValues[1])
             {
                 value = SIMD2<Float>(x, y) as! T
             } else if let simdValue = value as? SIMD3<Float>,
                       let x = Float(tempValues[0]),
                       let y = Float(tempValues[1]),
                       let z = Float(tempValues[2])
             {
                 value = SIMD3<Float>(x, y, z) as! T
             }

             DispatchQueue.main.async {
                 if focusedField == nil {
                     syncTempValues()
                 }
             }
         }
     }
     */

    public struct TextInputVectorView: View {
        let label: String
        @Binding var value: SIMD3<Float>
        @State private var tempValues: [String] = ["0", "0", "0"]
        @FocusState private var focusedField: Int?

        public init(label: String, value: Binding<SIMD3<Float>>) {
            self.label = label
            _value = value
        }

        public var body: some View {
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
                        .focused($focusedField, equals: index)
                        .onChange(of: value[index]) { _, newValue in
                            tempValues[index] = String(newValue) // Update when entity changes
                        }
                        .onSubmit {
                            if let newValue = Float(tempValues[index]) {
                                value[index] = newValue
                            }
                            focusedField = nil
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .onAppear {
                tempValues = [String(value.x), String(value.y), String(value.z)] // Convert explicitly
            }
        }
    }

    public struct TextInputNumberView: View {
        let label: String
        @Binding var value: Float
        @State private var tempValues: String = "0"
        @FocusState private var focusedField: Int?

        public init(label: String, value: Binding<Float>) {
            self.label = label
            _value = value
        }

        public var body: some View {
            VStack(alignment: .leading) {
                Text(label)
                    .font(.headline)

                HStack {
                    TextField("", text: Binding(
                        get: { tempValues },
                        set: { tempValues = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .focused($focusedField, equals: 1)
                    .onChange(of: value) { _, newValue in
                        tempValues = String(newValue) // Update when entity changes
                    }
                    .onSubmit {
                        if let newValue = Float(tempValues) {
                            value = newValue
                        }
                        focusedField = nil
                    }
                }
            }
            .padding(.vertical, 4)
            .onAppear {
                tempValues = String(value)
            }
        }
    }
#endif
