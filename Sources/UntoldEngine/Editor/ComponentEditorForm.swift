//
//  ComponentEditorForm.swift
//
//
//  Created by Harold Serrano on 8/10/25.
//

import Foundation
import SwiftUI

// 1) Describe the fields you want to render
public enum EditorField {
    case number(label: String,
                get: (EntityID) -> Float,
                set: (EntityID, Float) -> Void)

    case vector3(label: String,
                 get: (EntityID) -> SIMD3<Float>,
                 set: (EntityID, SIMD3<Float>) -> Void)
    
    case text(label: String,
                  placeholder: String?,
                  get: (EntityID) -> String,
                  set: (EntityID, String) -> Void)
}

// 2) Render fields into controls, wiring refreshView automatically
public struct ComponentForm: View {
    let entityId: EntityID
    let fields: [EditorField]
    let refresh: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                switch field {
                case let .number(label, get, set):
                    TextInputNumberView(
                        label: label,
                        value: Binding(
                            get: { get(entityId) },
                            set: { newValue in set(entityId, newValue); refresh() }
                        )
                    )

                case let .vector3(label, get, set):
                    TextInputVectorView(
                        label: label,
                        value: Binding(
                            get: { get(entityId) },
                            set: { newValue in set(entityId, newValue); refresh() }
                        )
                    )
                    
                case let .text(label, placeholder, get, set):
                                    HStack {
                                        Text(label)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        TextField(placeholder ?? "",
                                                  text: Binding(
                                                    get: { get(entityId) },
                                                    set: { newValue in set(entityId, newValue); refresh() }
                                                  )
                                        )
                                        .textFieldStyle(.roundedBorder)
                                    }
                }
                
            }
        }
    }
}

// 3) Helper to produce the `view:` closure you already use
public func makeEditorView(fields: [EditorField]) -> (EntityID?, Asset?, @escaping () -> Void) -> AnyView {
    { selectedId, _, refresh in
        AnyView(
            VStack(alignment: .leading, spacing: 12) {
                if let id = selectedId {
                    ComponentForm(entityId: id, fields: fields, refresh: refresh)
                }
            }
        )
    }
}
