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

    /// A build with nothing in it: what the cache holds does not matter to it.
    private func emptyBuild(_ path: String = "/tmp/Tree/Tree.untold") -> UntoldBuild {
        UntoldBuild(
            runtimeAsset: RuntimeAsset(
                sourceURL: URL(fileURLWithPath: path),
                sourceKind: .untold,
                assetName: "Tree",
                worldBounds: RuntimeAABB(min: .zero, max: .zero),
                meshGroups: []
            ),
            prebuiltMeshes: [:]
        )
    }

    private final class Results: @unchecked Sendable {
        private let lock = NSLock()
        private var builds: [UntoldBuild?] = []

        func append(_ build: UntoldBuild?) {
            lock.withLock { builds.append(build) }
        }

        var all: [UntoldBuild?] {
            lock.withLock { builds }
        }
    }

    func testConcurrentRequestsForOneFileBuildItOnce() async {
        let cache = UntoldBuildCache()
        let builds = Counter()
        let results = Results()
        let url = URL(fileURLWithPath: "/tmp/Tree/Tree.untold")
        let built = emptyBuild()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 32 {
                group.addTask {
                    let build = await cache.build(for: url) {
                        builds.increment()
                        Thread.sleep(forTimeInterval: 0.05)
                        return built
                    }
                    results.append(build)
                }
            }
        }

        XCTAssertEqual(builds.count, 1)
        XCTAssertEqual(cache.buildCount, 1)
        XCTAssertEqual(results.all.count, 32)
        XCTAssertTrue(results.all.allSatisfy { $0 === built }, "every caller gets the one build")
    }

    func testAnotherPathToTheSameFileIsTheSameBuild() async {
        let cache = UntoldBuildCache()
        let builds = Counter()
        let built = emptyBuild("/tmp/A.untold")

        for path in ["/tmp/A.untold", "/tmp/A.untold", "/tmp/./A.untold"] {
            let result = await cache.build(for: URL(fileURLWithPath: path)) {
                builds.increment()
                return built
            }
            XCTAssertTrue(result === built)
        }

        XCTAssertEqual(builds.count, 1)
    }

    func testABuildThatFailsOnceIsTriedAgain() async {
        let cache = UntoldBuildCache()
        let attempts = Counter()
        let url = URL(fileURLWithPath: "/tmp/Tree/Tree.untold")
        let built = emptyBuild()

        let first = await cache.build(for: url) {
            attempts.increment()
            // The first read fails, as a passing I/O error would make it.
            return attempts.count == 1 ? nil : built
        }
        let second = await cache.build(for: url) {
            attempts.increment()
            return nil
        }

        XCTAssertTrue(first === built, "the placement that met the error still gets its model")
        XCTAssertTrue(second === built)
        XCTAssertEqual(attempts.count, 2, "one retry, and nothing after the build succeeded")
    }

    func testAFileThatFailsTwiceIsRememberedAndOtherFilesBuildOnTheirOwn() async {
        let cache = UntoldBuildCache()
        let attempts = Counter()

        for path in ["/tmp/A.untold", "/tmp/A.untold", "/tmp/./A.untold", "/tmp/B.untold"] {
            let result = await cache.build(for: URL(fileURLWithPath: path)) {
                attempts.increment()
                return nil
            }
            XCTAssertNil(result)
        }

        XCTAssertEqual(attempts.count, 4, "A twice and never again (also through an unnormalised path), B twice")
        XCTAssertEqual(cache.buildCount, 2)
    }

    func testCallersWaitingForABuildThatFailsAllFallBack() async {
        let cache = UntoldBuildCache()
        let attempts = Counter()
        let results = Results()
        let url = URL(fileURLWithPath: "/tmp/Tree/Tree.untold")

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 16 {
                group.addTask {
                    let build = await cache.build(for: url) {
                        attempts.increment()
                        Thread.sleep(forTimeInterval: 0.03)
                        return nil
                    }
                    results.append(build)
                }
            }
        }

        XCTAssertEqual(attempts.count, 2, "the one caller that builds tries twice; the others wait for it")
        XCTAssertEqual(results.all.count, 16)
        XCTAssertTrue(results.all.allSatisfy { $0 == nil })
    }
}
