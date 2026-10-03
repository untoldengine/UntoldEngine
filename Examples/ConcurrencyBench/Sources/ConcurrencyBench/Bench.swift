//
//  Bench.swift
//  ConcurrencyBench
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import os
import Synchronization

let cores = ProcessInfo.processInfo.activeProcessorCount

// MARK: 1. Uncontended, synchronous caller (what the render loop is)

func uncontendedSync() {
    section("1. Uncontended, synchronous caller thread (ns per access)")
    let n = 5_000_000
    let stores: [(String, SyncStore)] = [
        ("no synchronisation (baseline)", PlainStore()),
        ("NSLock", NSLockStore()),
        ("NSRecursiveLock (engine globals today)", RecursiveLockStore()),
        ("OSAllocatedUnfairLock", UnfairLockStore()),
        ("Synchronization.Mutex", MutexStore()),
    ]
    for (name, store) in stores {
        measure(name, ops: n) {
            var sum: Float = 0
            for i in 0 ..< n {
                sum += store.op(i)
            }
            blackHole(sum)
        }
    }
    let serial = SerialQueueStore()
    let m = 1_000_000
    measure("serial DispatchQueue.sync", ops: m) {
        var sum: Float = 0
        for i in 0 ..< m {
            sum += serial.op(i)
        }
        blackHole(sum)
    }
    // Actor pinned to a queue, entered synchronously from that queue.
    let queue = DispatchSerialQueue(label: "bench.render")
    let pinned = QueueActorStore(queue: queue)
    measure("actor on own queue + assumeIsolated per access", ops: m) {
        queue.sync {
            var sum: Float = 0
            for i in 0 ..< m {
                sum += pinned.assumeIsolated { $0.op(i) }
            }
            blackHole(sum)
        }
    }
    measure("actor on own queue + assumeIsolated once per batch", ops: n) {
        queue.sync {
            pinned.assumeIsolated { a in
                var sum: Float = 0
                for i in 0 ..< n {
                    sum += a.op(i)
                }
                blackHole(sum)
            }
        }
    }
}

// MARK: 2. Uncontended, async caller

func uncontendedAsync() async {
    section("2. Uncontended, async caller (ns per access)")
    let n = 2_000_000
    let actor = ActorStore()
    let unfair = UnfairLockStore()

    await Task.detached {
        await measureAsync("task -> unfair lock", ops: n) {
            var sum: Float = 0
            for i in 0 ..< n {
                sum += unfair.op(i)
            }
            blackHole(sum)
        }
        await measureAsync("task -> actor, await per access", ops: n) {
            var sum: Float = 0
            for i in 0 ..< n {
                sum += await actor.op(i)
            }
            blackHole(sum)
        }
        await measureAsync("task -> actor, one await, loop inside the actor", ops: n) {
            await blackHole(actor.batch(n))
        }
        let caller = CallerActor()
        await measureAsync("actor A -> actor B, await per access", ops: n) {
            await blackHole(caller.drive(actor, n))
        }
    }.value

    let m = 100_000
    await measureAsync("MainActor -> actor, await per access (thread hop)", ops: m, runs: 5) { @MainActor in
        var sum: Float = 0
        for i in 0 ..< m {
            sum += await actor.op(i)
        }
        blackHole(sum)
    }
}

// MARK: 3. Contended

func contended() async {
    section("3. Contended: T workers on one shared state (ns per access, wall clock x T / total ops)")
    let perWorker = 200_000
    for t in [2, 4, 8] {
        let stores: [(String, SyncStore)] = [
            ("NSLock", NSLockStore()),
            ("NSRecursiveLock", RecursiveLockStore()),
            ("OSAllocatedUnfairLock", UnfairLockStore()),
            ("Synchronization.Mutex", MutexStore()),
        ]
        for (name, store) in stores {
            let s = UncheckedBox(store)
            measure("T=\(t) threads, \(name)", ops: perWorker, runs: 5) {
                DispatchQueue.concurrentPerform(iterations: t) { _ in
                    var sum: Float = 0
                    for i in 0 ..< perWorker {
                        sum += s.value.op(i)
                    }
                    blackHole(sum)
                }
            }
        }
        let unfair = UnfairLockStore()
        await measureAsync("T=\(t) tasks, OSAllocatedUnfairLock", ops: perWorker, runs: 5) {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0 ..< t {
                    group.addTask {
                        var sum: Float = 0
                        for i in 0 ..< perWorker {
                            sum += unfair.op(i)
                        }
                        blackHole(sum)
                    }
                }
            }
        }
        let actor = ActorStore()
        await measureAsync("T=\(t) tasks, actor (await per access)", ops: perWorker, runs: 5) {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0 ..< t {
                    group.addTask {
                        var sum: Float = 0
                        for i in 0 ..< perWorker {
                            sum += await actor.op(i)
                        }
                        blackHole(sum)
                    }
                }
            }
        }
    }
}

final class UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) {
        self.value = value
    }
}

// MARK: 4. Latency seen by a synchronous thread

@inline(never) func burn(milliseconds: Int) {
    let end = nowNs() + UInt64(milliseconds) * 1_000_000
    var x: UInt64 = 1
    while nowNs() < end {
        for _ in 0 ..< 2000 {
            x = x &* 6_364_136_223_846_793_005 &+ 1
        }
    }
    blackHole(x)
}

enum Load: String {
    case idle = "idle pool"
    case sameQoS = "pool saturated by 20 ms jobs, same priority"
    case lowQoS = "pool saturated by 20 ms jobs, utility priority"
}

/// Runs `body` on a dedicated user-interactive thread (stands in for the render thread).
func onRenderThread(_ body: @escaping @Sendable () -> Void) async {
    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
        let thread = Thread {
            body()
            c.resume()
        }
        thread.qualityOfService = .userInteractive
        thread.start()
    }
}

func latency() async {
    section("4. Time for a synchronous 'render' thread to get one value (µs)")
    let samples = 1500
    for load in [Load.idle, .sameQoS, .lowQoS] {
        print("-- \(load.rawValue)")
        let stop = Atomic<Bool>(false)
        let actor = ActorStore()
        let unfair = UnfairLockStore()
        var loaders: [Task<Void, Never>] = []
        if load != .idle {
            let priority: TaskPriority = load == .sameQoS ? .userInitiated : .utility
            for k in 0 ..< cores * 2 {
                loaders.append(Task.detached(priority: priority) {
                    while !stop.load(ordering: .relaxed) {
                        burn(milliseconds: 20)
                        // Report progress to both, as a loader would.
                        blackHole(unfair.op(k))
                        await blackHole(actor.op(k))
                    }
                })
            }
            try? await Task.sleep(for: .milliseconds(200))
        }

        await onRenderThread {
            var ns = [UInt64](); ns.reserveCapacity(samples)
            for i in 0 ..< samples {
                let t0 = nowNs()
                blackHole(unfair.op(i))
                ns.append(nowNs() - t0)
                usleep(300)
            }
            percentiles("unfair lock", ns)
        }
        await onRenderThread {
            var ns = [UInt64](); ns.reserveCapacity(samples)
            let sem = DispatchSemaphore(value: 0)
            for i in 0 ..< samples {
                let t0 = nowNs()
                Task(priority: .userInitiated) {
                    await blackHole(actor.op(i))
                    sem.signal()
                }
                sem.wait()
                ns.append(nowNs() - t0)
                usleep(300)
            }
            percentiles("actor through Task + semaphore (blocking bridge)", ns)
        }
        // Fire-and-forget: how late does the actor see the message?
        await onRenderThread {
            let done = DispatchSemaphore(value: 0)
            let box = LatencyBox(capacity: samples)
            for i in 0 ..< samples {
                let t0 = nowNs()
                Task(priority: .userInitiated) {
                    await blackHole(actor.op(i))
                    box.add(nowNs() - t0)
                    if i == samples - 1 {
                        done.signal()
                    }
                }
                usleep(300)
            }
            done.wait()
            usleep(50000)
            percentiles("actor, fire-and-forget Task: delay until it runs", box.snapshot())
        }

        stop.store(true, ordering: .relaxed)
        for l in loaders {
            await l.value
        }
    }

    print("-- main thread round trip from a background thread (editor case), idle")
    await onRenderThread {
        var ns = [UInt64]()
        let sem = DispatchSemaphore(value: 0)
        for _ in 0 ..< samples {
            let t0 = nowNs()
            DispatchQueue.main.async { sem.signal() }
            sem.wait()
            ns.append(nowNs() - t0)
            usleep(300)
        }
        percentiles("DispatchQueue.main.async round trip", ns)
    }
    await onRenderThread {
        var ns = [UInt64]()
        let sem = DispatchSemaphore(value: 0)
        for _ in 0 ..< samples {
            let t0 = nowNs()
            Task { @MainActor in sem.signal() }
            sem.wait()
            ns.append(nowNs() - t0)
            usleep(300)
        }
        percentiles("Task { @MainActor } round trip", ns)
    }
}

final class LatencyBox: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: [UInt64]())
    init(capacity: Int) {
        lock.withLock { $0.reserveCapacity(capacity) }
    }

    func add(_ v: UInt64) {
        lock.withLock { $0.append(v) }
    }

    func snapshot() -> [UInt64] {
        lock.withLock { $0 }
    }
}

// MARK: 5. A frame over 10k entities

struct World {
    var transforms: [SIMD4<Float>]
    var bounds: [SIMD4<Float>]
    var flags: [UInt32]
    init(count: Int) {
        transforms = (0 ..< count).map { SIMD4(Float($0), 1, 2, 3) }
        bounds = (0 ..< count).map { SIMD4(1, Float($0), 2, 3) }
        flags = (0 ..< count).map { UInt32($0 & 7) }
    }

    @inline(__always) mutating func touch(_ f: Int) {
        transforms[f % transforms.count].x += 1; flags[f % flags.count] &+= 1
    }

    @inline(__always) func transform(_ e: Int) -> SIMD4<Float> {
        transforms[e]
    }

    @inline(__always) func bound(_ e: Int) -> SIMD4<Float> {
        bounds[e]
    }

    @inline(__always) func flag(_ e: Int) -> UInt32 {
        flags[e]
    }
}

@inline(__always) func combine(_ t: SIMD4<Float>, _ b: SIMD4<Float>, _ f: UInt32) -> Float {
    f & 1 == 0 ? (t * b).sum() : t.x
}

final class LockedWorld<L: NSLocking>: @unchecked Sendable {
    var world: World
    let lock: L
    init(count: Int, lock: L) {
        world = World(count: count); self.lock = lock
    }

    @inline(never) func transform(_ e: Int) -> SIMD4<Float> {
        lock.lock(); defer { lock.unlock() }; return world.transform(e)
    }

    @inline(never) func bound(_ e: Int) -> SIMD4<Float> {
        lock.lock(); defer { lock.unlock() }; return world.bound(e)
    }

    @inline(never) func flag(_ e: Int) -> UInt32 {
        lock.lock(); defer { lock.unlock() }; return world.flag(e)
    }

    func touch(_ f: Int) {
        lock.lock(); world.touch(f); lock.unlock()
    }
}

final class UnfairWorld: @unchecked Sendable {
    let lock: OSAllocatedUnfairLock<World>
    init(count: Int) {
        lock = OSAllocatedUnfairLock(initialState: World(count: count))
    }

    @inline(never) func transform(_ e: Int) -> SIMD4<Float> {
        lock.withLock { $0.transform(e) }
    }

    @inline(never) func bound(_ e: Int) -> SIMD4<Float> {
        lock.withLock { $0.bound(e) }
    }

    @inline(never) func flag(_ e: Int) -> UInt32 {
        lock.withLock { $0.flag(e) }
    }

    func touch(_ f: Int) {
        lock.withLock { $0.touch(f) }
    }

    @inline(never) func frame(_ count: Int) -> Float {
        lock.withLock { w in
            var sum: Float = 0
            for e in 0 ..< count {
                sum += combine(w.transform(e), w.bound(e), w.flag(e))
            }
            return sum
        }
    }
}

actor WorldActor {
    var world: World
    init(count: Int) {
        world = World(count: count)
    }

    func transform(_ e: Int) -> SIMD4<Float> {
        world.transform(e)
    }

    func bound(_ e: Int) -> SIMD4<Float> {
        world.bound(e)
    }

    func flag(_ e: Int) -> UInt32 {
        world.flag(e)
    }

    func touch(_ f: Int) {
        world.touch(f)
    }

    func frame(_ count: Int, _ f: Int) -> Float {
        world.touch(f)
        var sum: Float = 0
        for e in 0 ..< count {
            sum += combine(transform(e), bound(e), flag(e))
        }
        return sum
    }
}

final class PlainWorld: @unchecked Sendable {
    var world: World
    init(count: Int) {
        world = World(count: count)
    }

    @inline(never) func frame(_ count: Int, _ f: Int) -> Float {
        world.touch(f)
        var sum: Float = 0
        for e in 0 ..< count {
            sum += combine(world.transform(e), world.bound(e), world.flag(e))
        }
        return sum
    }
}

func frameSimulation() async {
    section("5. One system pass over 10,000 entities, 3 component reads each (µs per frame)")
    let count = 10000
    let frames = 200
    func perFrame(_ name: String, _ body: (Int) -> Float) {
        var samples: [Double] = []
        for _ in 0 ..< 7 {
            let t0 = nowNs()
            var sum: Float = 0
            for f in 0 ..< frames {
                sum += body(f)
            }
            blackHole(sum)
            samples.append(Double(nowNs() - t0) / Double(frames) / 1000)
        }
        record(name, samples: samples, unit: "µs/frame")
    }
    let plain = PlainWorld(count: count)
    perFrame("no synchronisation") { f in plain.frame(count, f) }
    let recursive = LockedWorld(count: count, lock: NSRecursiveLock())
    perFrame("NSRecursiveLock per read (engine today)") { f in
        recursive.touch(f)
        var sum: Float = 0
        for e in 0 ..< count {
            sum += combine(recursive.transform(e), recursive.bound(e), recursive.flag(e))
        }
        return sum
    }
    let unfair = UnfairWorld(count: count)
    perFrame("unfair lock per read") { f in
        unfair.touch(f)
        var sum: Float = 0
        for e in 0 ..< count {
            sum += combine(unfair.transform(e), unfair.bound(e), unfair.flag(e))
        }
        return sum
    }
    perFrame("unfair lock once per frame") { f in unfair.touch(f); return unfair.frame(count) }

    let actor = WorldActor(count: count)
    await Task.detached {
        var a: [Double] = [], b: [Double] = []
        for _ in 0 ..< 7 {
            var t0 = nowNs()
            var sum: Float = 0
            for f in 0 ..< frames {
                await actor.touch(f)
                for e in 0 ..< count {
                    await sum += combine(actor.transform(e), actor.bound(e), actor.flag(e))
                }
            }
            a.append(Double(nowNs() - t0) / Double(frames) / 1000)
            t0 = nowNs()
            for f in 0 ..< frames {
                sum += await actor.frame(count, f)
            }
            b.append(Double(nowNs() - t0) / Double(frames) / 1000)
            blackHole(sum)
        }
        record("actor, await per read", samples: a, unit: "µs/frame")
        record("actor, system runs inside the actor (one hop per frame)", samples: b, unit: "µs/frame")
    }.value
}

@main
enum Bench {
    static func main() async {
        print("cores: \(cores), \(ProcessInfo.processInfo.operatingSystemVersionString)")
        let only = CommandLine.arguments.dropFirst().first
        if only == nil || only == "1" {
            uncontendedSync()
        }
        if only == nil || only == "2" {
            await uncontendedAsync()
        }
        if only == nil || only == "3" {
            await contended()
        }
        if only == nil || only == "4" {
            await latency()
        }
        if only == nil || only == "5" {
            await frameSimulation()
        }
    }
}
