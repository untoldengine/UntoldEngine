//
//  TestSynchronization.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

// Guards tests that mutate InputSystem.shared XR spatial state so they do not
// race when XCTest executes classes in parallel.
let xrInputSingletonTestLock = NSLock()
