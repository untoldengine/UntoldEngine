//
//  UntoldGSCookControl.swift
//  UntoldEngine
//
//  Progress and cancellation for a Gaussian splat cook: the phases a bake runs
//  through, the callback that reports them, and the hook a caller cancels with.
//  Honoured between windows of the source and between chunk batches of the
//  writer, so a cook stops within a fraction of a second and leaves no partial
//  file behind.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// The phases of `bakeGaussianSplatProgressiveTiers`, in order. `read` and `cook` run once over
/// the source; `chunk`, `coarsen` and `write` run once per tier. `coarsen` is reported only when
/// the tier bakes coarse levels (`UntoldGSCookOptions.coarseLevels`).
public enum UntoldGSCookPhase: String, Sendable, CaseIterable {
    /// Parsing the source in windows (fraction = source bytes consumed). The per-splat cook —
    /// prune, transform, crop — runs inside the same pass.
    case read
    /// Budget selection and bounds (the first half), then the progressive ranking of a
    /// multi-tier bake (the second half, polled as it runs).
    case cook
    /// Morton ordering, chunk layout and, without coarse levels, the chunk encode.
    case chunk
    /// Per-chunk encode and coarsening (fraction = chunks done).
    case coarsen
    /// Coarse section, header, index and the atomic rename.
    case write
}

/// One progress report of a cook.
public struct UntoldGSCookProgress: Sendable, Equatable {
    public var phase: UntoldGSCookPhase
    /// Within the phase, 0…1.
    public var fraction: Float
    /// Across the whole bake, 0…1; reaches 1 with the last tier's `write`.
    public var overall: Float
    /// The tier being baked (0 during `read` and `cook`).
    public var tierIndex: Int
    public var tierCount: Int

    public init(phase: UntoldGSCookPhase, fraction: Float, overall: Float, tierIndex: Int, tierCount: Int) {
        self.phase = phase
        self.fraction = fraction
        self.overall = overall
        self.tierIndex = tierIndex
        self.tierCount = tierCount
    }
}

/// What a caller hands a cook to follow and stop it. Both closures run on the cooking thread,
/// between windows and chunk batches; a cook also stops when the `Task` it runs in is cancelled.
public struct UntoldGSCookControl: Sendable {
    public var progress: (@Sendable (UntoldGSCookProgress) -> Void)?
    /// Polled between windows and chunk batches; `true` ends the cook with
    /// `UntoldGSCookError.cancelled` and nothing written.
    public var isCancelled: (@Sendable () -> Bool)?

    public init(
        progress: (@Sendable (UntoldGSCookProgress) -> Void)? = nil,
        isCancelled: (@Sendable () -> Bool)? = nil
    ) {
        self.progress = progress
        self.isCancelled = isCancelled
    }

    /// Throws `UntoldGSCookError.cancelled` when the caller or the current task asked to stop.
    public func checkCancelled() throws {
        if Task.isCancelled || isCancelled?() == true {
            throw UntoldGSCookError.cancelled
        }
    }
}

/// The bake's progress bookkeeping: phase weights, the tier being baked, and the callback.
/// `read` and `cook` take a share of the whole; the tiers split the rest evenly.
final class UntoldGSCookProgressSink: @unchecked Sendable {
    let control: UntoldGSCookControl?
    let tierCount: Int
    private(set) var tierIndex = 0
    /// Whether the tier being baked reports `coarsen`; the writer says once it knows.
    private(set) var tierHasCoarseLevels = true
    /// Per-tier weights, by phase; `read` and `cook` come first.
    private static let readWeight: Float = 0.35
    private static let cookWeight: Float = 0.05
    private static let tierWeights: [UntoldGSCookPhase: Float] = [.chunk: 0.10, .coarsen: 0.40, .write: 0.10]
    /// Without coarse levels the chunk loop — the encode, most of the tier's time — reports as
    /// `chunk`, which takes the coarsening's share so `overall` keeps moving through it
    /// instead of leaping when `write` starts.
    private static let tierWeightsWithoutCoarseLevels: [UntoldGSCookPhase: Float] = [.chunk: 0.50, .coarsen: 0, .write: 0.10]
    private static let tierWeightTotal: Float = 0.60

    init(control: UntoldGSCookControl?, tierCount: Int) {
        self.control = control
        self.tierCount = max(1, tierCount)
    }

    func beginTier(_ index: Int) {
        tierIndex = index
        tierHasCoarseLevels = true
    }

    /// Told by the writer, before its first report of the tier, whether the tier bakes coarse
    /// levels — and so whether `coarsen` will be reported at all.
    func setTierHasCoarseLevels(_ hasCoarseLevels: Bool) {
        tierHasCoarseLevels = hasCoarseLevels
    }

    /// Reports `phase` at `fraction`, mapping it onto the whole bake, and polls cancellation.
    func report(_ phase: UntoldGSCookPhase, fraction: Double) throws {
        try control?.checkCancelled()
        guard let progress = control?.progress else { return }
        let f = Float(min(max(fraction, 0), 1))
        let overall: Float
        switch phase {
        case .read:
            overall = Self.readWeight * f
        case .cook:
            overall = Self.readWeight + Self.cookWeight * f
        case .chunk, .coarsen, .write:
            let weights = tierHasCoarseLevels ? Self.tierWeights : Self.tierWeightsWithoutCoarseLevels
            let perTier = Self.tierWeightTotal / Float(tierCount)
            var withinTier: Float = 0
            for earlier in [UntoldGSCookPhase.chunk, .coarsen, .write] {
                if earlier == phase {
                    withinTier += (weights[earlier] ?? 0) * f
                    break
                }
                withinTier += weights[earlier] ?? 0
            }
            overall = Self.readWeight + Self.cookWeight + perTier * (Float(tierIndex) + withinTier / Self.tierWeightTotal)
        }
        progress(UntoldGSCookProgress(phase: phase, fraction: f, overall: min(overall, 1), tierIndex: tierIndex, tierCount: tierCount))
    }

    func checkCancelled() throws {
        try control?.checkCancelled()
    }
}
