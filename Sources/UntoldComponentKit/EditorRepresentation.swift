//
//  EditorRepresentation.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// What the editor draws for an entity on top of, or instead of, its geometry: the flag of a
/// spawn point, the control points of a spline. It belongs to the entity (`EntityPlugin`), it
/// is drawn only while editing, it is never saved, and it does not exist in a game.
///
/// Positions are in the entity's local space, so the drawing moves, turns and scales with it.
public struct EditorRepresentation: Equatable, Sendable {
    public enum Item: Equatable, Sendable {
        /// A camera-facing icon at the entity's origin, hidden by geometry in front of it like
        /// the editor's light markers. `systemImage` is an SF Symbol name; `tint` is RGB, 0 to 1.
        case icon(systemImage: String, tint: SIMD3<Float>)
        /// A dot at each position, drawn over everything so a handle inside a mesh stays visible.
        case points([SIMD3<Float>], tint: SIMD3<Float>)
        /// A line through the positions, drawn over everything. `closed` joins the last to the first.
        case polyline([SIMD3<Float>], closed: Bool)
    }

    public var items: [Item]

    public init(_ items: [Item] = []) {
        self.items = items
    }

    /// Nothing is drawn. Right for an entity whose geometry says it all, and for one that
    /// needs no marker.
    public static let none = EditorRepresentation()

    /// Just an icon.
    public static func icon(systemImage: String, tint: SIMD3<Float> = SIMD3<Float>(1, 1, 1)) -> EditorRepresentation {
        EditorRepresentation([.icon(systemImage: systemImage, tint: tint)])
    }

    public var isEmpty: Bool {
        items.isEmpty
    }
}
