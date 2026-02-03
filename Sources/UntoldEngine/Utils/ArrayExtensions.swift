//
//  ArrayExtensions.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

extension Array {
    /// Safe subscript that returns nil instead of crashing for out-of-bounds access
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
