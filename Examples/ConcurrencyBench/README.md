# ConcurrencyBench

Measures what a Swift actor costs next to the lock mechanisms the engine can use
(`NSLock`, `NSRecursiveLock`, `OSAllocatedUnfairLock`, `Synchronization.Mutex`,
a serial `DispatchQueue`). It does not depend on the engine.

Results and the rules drawn from them: `docs/proposals/ActorsAndLocks.md`.

```bash
swift run -c release --package-path Examples/ConcurrencyBench
```

Pass a section number to run one section:

| Section | What it measures |
|---|---|
| 1 | One access from a synchronous thread, no contention |
| 2 | One access from an async caller, no contention |
| 3 | 2, 4 and 8 workers on one shared state |
| 4 | How long a synchronous thread waits for one value, with the thread pool idle and saturated |
| 5 | One system pass over 10,000 entities |

Needs macOS 15 (for `Mutex`). Always run a release build; each row prints the minimum and the median of its runs.
