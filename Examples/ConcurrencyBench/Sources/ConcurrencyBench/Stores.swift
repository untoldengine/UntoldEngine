//
//  Stores.swift
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

let storeSize = 1024
let storeMask = storeSize - 1

struct State {
    var values = [Float](repeating: 1, count: storeSize)

    @inline(__always)
    mutating func op(_ i: Int) -> Float {
        values[i & storeMask] += 1
        return values[i & storeMask]
    }
}

protocol SyncStore: AnyObject {
    func op(_ i: Int) -> Float
}

final class PlainStore: SyncStore, @unchecked Sendable {
    var state = State()
    @inline(never) func op(_ i: Int) -> Float {
        state.op(i)
    }
}

final class NSLockStore: SyncStore, @unchecked Sendable {
    var state = State()
    let lock = NSLock()
    @inline(never) func op(_ i: Int) -> Float {
        lock.lock(); defer { lock.unlock() }
        return state.op(i)
    }
}

final class RecursiveLockStore: SyncStore, @unchecked Sendable {
    var state = State()
    let lock = NSRecursiveLock()
    @inline(never) func op(_ i: Int) -> Float {
        lock.lock(); defer { lock.unlock() }
        return state.op(i)
    }
}

final class UnfairLockStore: SyncStore, @unchecked Sendable {
    let lock = OSAllocatedUnfairLock(initialState: State())
    @inline(never) func op(_ i: Int) -> Float {
        lock.withLock { $0.op(i) }
    }
}

final class MutexStore: SyncStore, @unchecked Sendable {
    let mutex = Mutex(State())
    @inline(never) func op(_ i: Int) -> Float {
        mutex.withLock { $0.op(i) }
    }
}

final class SerialQueueStore: SyncStore, @unchecked Sendable {
    var state = State()
    let queue = DispatchQueue(label: "bench.serial")
    @inline(never) func op(_ i: Int) -> Float {
        queue.sync { state.op(i) }
    }
}

actor ActorStore {
    var state = State()
    @inline(never) func op(_ i: Int) -> Float {
        state.op(i)
    }

    func batch(_ n: Int) -> Float {
        var sum: Float = 0
        for i in 0 ..< n {
            sum += op(i)
        }
        return sum
    }
}

/// A second actor that calls into `ActorStore` (actor-to-actor hop per call).
actor CallerActor {
    func drive(_ store: ActorStore, _ n: Int) async -> Float {
        var sum: Float = 0
        for i in 0 ..< n {
            sum += await store.op(i)
        }
        return sum
    }
}

/// Actor pinned to a serial dispatch queue: the owning thread can enter it
/// synchronously with `assumeIsolated`.
actor QueueActorStore {
    let queue: DispatchSerialQueue
    var state = State()
    init(queue: DispatchSerialQueue) {
        self.queue = queue
    }

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    @inline(never) func op(_ i: Int) -> Float {
        state.op(i)
    }
}
