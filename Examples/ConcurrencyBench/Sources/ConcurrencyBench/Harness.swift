//
//  Harness.swift
//  ConcurrencyBench
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@inline(never) func blackHole(_: some Any) {}

@inline(__always) func nowNs() -> UInt64 {
    DispatchTime.now().uptimeNanoseconds
}

struct Result {
    let name: String
    let minNs: Double
    let medianNs: Double
}

nonisolated(unsafe) var results: [(section: String, Result)] = []
nonisolated(unsafe) var currentSection = ""

func section(_ name: String) {
    currentSection = name
    print("\n== \(name)")
}

func record(_ name: String, samples: [Double], unit: String = "ns/op") {
    let sorted = samples.sorted()
    let r = Result(name: name, minNs: sorted[0], medianNs: sorted[sorted.count / 2])
    results.append((currentSection, r))
    let pad = name.padding(toLength: 58, withPad: " ", startingAt: 0)
    print(String(format: "%@ min %10.1f  median %10.1f  %@", pad, r.minNs, r.medianNs, unit))
}

func measure(_ name: String, ops: Int, runs: Int = 7, _ body: () -> Void) {
    var samples: [Double] = []
    for _ in 0 ..< runs {
        let t0 = nowNs()
        body()
        samples.append(Double(nowNs() - t0) / Double(ops))
    }
    record(name, samples: samples)
}

func measureAsync(_ name: String, ops: Int, runs: Int = 7, _ body: () async -> Void) async {
    var samples: [Double] = []
    for _ in 0 ..< runs {
        let t0 = nowNs()
        await body()
        samples.append(Double(nowNs() - t0) / Double(ops))
    }
    record(name, samples: samples)
}

func percentiles(_ name: String, _ ns: [UInt64]) {
    let s = ns.sorted()
    func p(_ q: Double) -> Double {
        Double(s[min(s.count - 1, Int(Double(s.count) * q))]) / 1000
    }
    let pad = name.padding(toLength: 58, withPad: " ", startingAt: 0)
    print(String(format: "%@ p50 %9.2f  p99 %9.2f  max %9.2f  µs", pad, p(0.5), p(0.99), Double(s[s.count - 1]) / 1000))
}
