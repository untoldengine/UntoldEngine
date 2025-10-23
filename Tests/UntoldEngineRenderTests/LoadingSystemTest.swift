//
//  LoadingSystemTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import CShaderTypes
import Foundation
@testable import UntoldEngine
import XCTest

final class LoadingSystemTest: XCTestCase {
    override func setUp() {
        let bundleURL = Bundle.module.resourceURL
        assetBasePath = bundleURL
    }

    override func tearDown() {
        super.tearDown()
    }

    func assertResourceExists(_ name: String, _ ext: String,
                              structuredSubdir: String? = nil,
                              file: StaticString = #filePath, line: UInt = #line)
    {
        let base = Bundle.module.resourceURL!
        let fm = FileManager.default

        // 1) flat
        let flatPath = base.appendingPathComponent("\(name).\(ext)").path
        if fm.fileExists(atPath: flatPath) { return }

        // 2) structured (if provided)
        if let sub = structuredSubdir {
            let structPath = base.appendingPathComponent(sub)
                .appendingPathComponent("\(name).\(ext)").path
            if fm.fileExists(atPath: structPath) { return }
        }

        // 3) Bundle query (in case of odd packaging)
        let bundle = Bundle(url: Bundle.module.bundleURL)!
        if bundle.url(forResource: name, withExtension: ext, subdirectory: structuredSubdir) != nil { return }
        if bundle.url(forResource: name, withExtension: ext) != nil { return }

        XCTFail("❌ Missing resource \(name).\(ext) (flat or under \(structuredSubdir ?? "<none>"))",
                file: file, line: line)
    }

    func test_essentialAssetsExist_anyLayout() {
        assertResourceExists("ball", "usdz", structuredSubdir: "Models/ball")
        assertResourceExists("redplayer", "usdz", structuredSubdir: "Models/redplayer")
        assertResourceExists("stadium", "usdz", structuredSubdir: "Models/stadium")
        assertResourceExists("idle", "usdz", structuredSubdir: "Animations/idle")
        assertResourceExists("running", "usdz", structuredSubdir: "Animations/running")
    }

    func test_engineResolverFindsThem() {
        for (name, ext) in [("ball", "usdz"), ("redplayer", "usdz"), ("stadium", "usdz")] {
            XCTAssertNotNil(getResourceURL(resourceName: name, ext: ext, subName: nil),
                            "Engine failed to locate \(name).\(ext)")
        }
    }
}
