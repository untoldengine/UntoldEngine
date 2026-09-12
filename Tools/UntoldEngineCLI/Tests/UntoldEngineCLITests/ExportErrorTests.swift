//
//  ExportErrorTests.swift
//  UntoldEngineCLI
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngineCLI
import XCTest

final class ExportErrorTests: XCTestCase {
    func testOutputWriteFailureNamesThePathAndTheSystemsReason() {
        // The writer's `pwrite` on a full volume: the user reads the path and "No space left on
        // device", not an NSError dump under an "invalid input" label.
        let full = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC), userInfo: [NSFilePathErrorKey: "/Volumes/Captures/.scene.untoldgs.tmp-1"])
        let description = ExportError.outputWriteFailure(full).errorDescription
        XCTAssertEqual(description, "Failed to write Gaussian splat output /Volumes/Captures/.scene.untoldgs.tmp-1: No space left on device")

        let cocoa = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [NSLocalizedDescriptionKey: "You don’t have permission."])
        XCTAssertEqual(ExportError.outputWriteFailure(cocoa).errorDescription, "Failed to write Gaussian splat output: You don’t have permission.")
    }
}
