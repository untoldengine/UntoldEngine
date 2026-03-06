//
//  TestSynchronization.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

// Guards tests that mutate InputSystem.shared XR spatial state so they do not
// race when XCTest executes classes in parallel.
let xrInputSingletonTestLock = NSLock()
