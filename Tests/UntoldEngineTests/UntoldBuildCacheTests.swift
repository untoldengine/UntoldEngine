//
//  UntoldBuildCacheTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

/// The pack loader's single-flight build cache (see UntoldBuildCache): concurrent
/// placements of one file build it once.
final class UntoldBuildCacheTests: XCTestCase {
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func increment() {
            lock.withLock { value += 1 }
        }

        var count: Int {
            lock.withLock { value }
        }
    }

    func testConcurrentRequestsForOneFileBuildItOnce() async {
        let cache = UntoldBuildCache()
        let builds = Counter()
        let url = URL(fileURLWithPath: "/tmp/Tree/Tree.untold")

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 32 {
                group.addTask {
                    _ = await cache.build(for: url) {
                        builds.increment()
                        Thread.sleep(forTimeInterval: 0.05)
                        return nil
                    }
                }
            }
        }

        XCTAssertEqual(builds.count, 1)
        XCTAssertEqual(cache.buildCount, 1)
    }

    func testAFailedBuildIsRememberedAndOtherFilesBuildOnTheirOwn() async {
        let cache = UntoldBuildCache()
        let builds = Counter()

        for path in ["/tmp/A.untold", "/tmp/A.untold", "/tmp/./A.untold", "/tmp/B.untold"] {
            let result = await cache.build(for: URL(fileURLWithPath: path)) {
                builds.increment()
                return nil
            }
            XCTAssertNil(result)
        }

        XCTAssertEqual(builds.count, 2, "A once (also through an unnormalised path), B once")
    }
}
