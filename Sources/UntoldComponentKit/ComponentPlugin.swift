//
//  ComponentPlugin.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// Base class for a component written in code: something that can be added to any entity.
///
/// Subclass it (`final` recommended), mark what the editor should see with `@UntoldAttribute`,
/// and override the lifecycle methods you need. The editor lists every loaded subclass in the
/// Inspector's Add Component menu, and an entity carries at most one of each.
///
///     final class Spinner: ComponentPlugin {
///         @UntoldAttribute("Speed", range: 0 ... 720) var speed: Float = 90
///
///         override func onUpdate(deltaTime: Float) { /* turn the entity */ }
///     }
///
/// Whatever belongs to one kind of entity only (the ring of a torus, the curve of a spline) is
/// not a component: it is part of that entity, and goes on its `EntityPlugin`.
open class ComponentPlugin: ScenePlugin {}
