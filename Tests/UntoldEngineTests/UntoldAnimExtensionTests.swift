//
//  UntoldAnimExtensionTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

@testable import UntoldEngine
import XCTest

final class UntoldAnimExtensionTests: XCTestCase {
    func testRuntimeAssetSourceInfersUntoldAnimAsUntoldKind() {
        let url = URL(fileURLWithPath: "/tmp/walk.untoldanim")
        XCTAssertEqual(RuntimeAssetSource.infer(from: url).kind, .untold)
    }

    func testRuntimeAssetSourceStillInfersPlainUntold() {
        let url = URL(fileURLWithPath: "/tmp/Robot.untold")
        XCTAssertEqual(RuntimeAssetSource.infer(from: url).kind, .untold)
    }
}
