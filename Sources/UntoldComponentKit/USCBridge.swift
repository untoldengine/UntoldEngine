//
//  USCBridge.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// Publishes component actions to USC scripts as `"<TypeName>.<ActionName>"`.
///
/// The action runs on the component attached to the script's own entity, so
/// `callAction("PlayerController.Jump")` needs no target argument.
enum USCBridge {
    static func actionName(typeName: String, action: String) -> String {
        "\(typeName).\(action)"
    }

    static func registerActions(for type: CodeComponent.Type) {
        let typeName = type.typeName
        for action in type.actions {
            USCActionRegistry.shared.register(name: actionName(typeName: typeName, action: action.name)) { context, _ in
                guard let instance = CodeComponentSystem.shared.component(named: typeName, on: context.entityId) else {
                    return nil
                }
                action.perform(on: instance)
                return nil
            }
        }
    }

    static func unregisterActions(for type: CodeComponent.Type) {
        let typeName = type.typeName
        for action in type.actions {
            USCActionRegistry.shared.unregister(name: actionName(typeName: typeName, action: action.name))
        }
    }
}
