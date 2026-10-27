//
//  SimulationStepping.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// How the game-mode simulation loop is stepped against the frames. The built-in integrator,
/// every `EngineExtension` and `RenderExtension` `fixedUpdate` (the external physics backend
/// through `PhysicsCoordinator`, code components through `ScenePluginSystem`) and the legacy
/// custom systems all run inside that loop, so the mode decides the delta each of them sees.
/// See `EngineProperty.simulationStepping`.
public enum SimulationStepping: Sendable, Equatable {
    /// One 1/60 s step for every 1/60 s of frame time accumulated, five at most in a frame,
    /// the remainder carried to the next: the default, and the same simulation on every
    /// display. A display faster than 60 Hz has frames in which nothing is stepped (two in
    /// five at 100 Hz, one in three at 90 Hz), so whatever only moves in a step stands still
    /// on them while the animation moves on.
    case fixed
    /// One pass every frame with the frame's own delta, so the simulation lands on every frame
    /// at any refresh rate. A frame longer than a step is divided into equal sub-steps, none
    /// longer than 1.1/60 s (a tenth of a step of slack keeps a jittered 60 Hz frame whole
    /// instead of halving it), five at most; nothing is carried to the next frame, so a frame
    /// longer than 5/60 s simulates 5/60 s, and a frame shorter than 1/250 s (a second draw
    /// for one refresh, not a frame of the display) simulates nothing. Every `fixedUpdate`
    /// then sees a varying delta, and the simulation follows the display's cadence rather
    /// than one fixed sequence.
    case perFrame
}

/// The steps one frame of game-mode simulation runs — how many, how long each, and what the
/// accumulator carries to the next frame — from the stepping mode, the frame's delta and the
/// value carried in. Pure, so the policy is tested without a frame: `updateSimulationSteps`
/// asks for a plan and runs it.
struct SimulationStepPlan: Equatable, Sendable {
    /// The most steps one frame runs in either mode: the fixed loop's catch-up clamp, and the
    /// per-frame mode's bound on how finely a long frame is divided.
    static let maxSteps = 5
    /// The share of a step a per-frame delta may exceed a whole number of steps by and still
    /// run that number: a 60 Hz frame's wall-clock jitter (16.6 to 16.8 ms) is noise, not a
    /// reason to halve the step. It absorbs jitter, not a cadence: 20 ms is two steps.
    static let wholeStepTolerance: Float = 0.1
    /// The shortest frame the per-frame mode steps: a spacing under 1/250 s is a second draw
    /// for one refresh rather than a period of the display, under every refresh rate the engine
    /// runs at. A shorter frame simulates nothing: stepping a sliver would hand every
    /// `fixedUpdate` a near-zero delta, and a backend that moves a kinematic body onto its
    /// target within `deltaTime` would give it an absurd velocity for that step, and whatever
    /// it touches an impact to match.
    static let shortestFrame: Float = 1.0 / 250.0

    let stepCount: Int
    let stepDelta: Float
    /// What the next frame starts from: under one fixed step in `.fixed`; 0 in `.perFrame`,
    /// which carries nothing, so a switch between the modes drops the residual.
    let accumulator: Float

    init(stepping: SimulationStepping, frameDelta: Float, accumulator: Float, fixedStep: Float) {
        switch stepping {
        case .fixed:
            // The loop as it was, operation for operation: the carried value is bit-identical.
            var carried = accumulator + frameDelta
            var count = 0
            while carried >= fixedStep, count < Self.maxSteps {
                carried -= fixedStep
                count += 1
            }
            stepCount = count
            stepDelta = fixedStep
            self.accumulator = carried
        case .perFrame:
            // A non-finite delta runs nothing (`Int(.nan)` traps, and in XR this runs on the
            // compositor's render thread), and so does one under the shortest frame.
            guard frameDelta.isFinite, frameDelta >= Self.shortestFrame else {
                stepCount = 0
                stepDelta = 0
                self.accumulator = 0
                return
            }
            let simulated = min(frameDelta, Float(Self.maxSteps) * fixedStep)
            let wanted = (simulated / fixedStep - Self.wholeStepTolerance).rounded(.up)
            let count = min(Self.maxSteps, max(1, Int(wanted)))
            stepCount = count
            stepDelta = simulated / Float(count)
            self.accumulator = 0
        }
    }
}

/// The game-mode simulation stage of a frame: plans the frame's steps from the stepping mode,
/// the frame's delta and the accumulator (each read once, the accumulator written once), then
/// runs the built-in integrator, every registered extension's `fixedUpdate` and the legacy
/// custom systems once per step at the plan's delta. Internal so a test drives it without a
/// frame; `runFrame` calls it between the animation update and the game update.
@discardableResult
func updateSimulationSteps(deltaTime: Float, context: EngineExtensionUpdateContext) -> SimulationStepPlan {
    let plan = SimulationStepPlan(
        stepping: simulationStepping,
        frameDelta: deltaTime,
        accumulator: physicsAccumulator,
        fixedStep: fixedStep
    )
    physicsAccumulator = plan.accumulator
    for _ in 0 ..< plan.stepCount {
        updatePhysicsSystem(deltaTime: plan.stepDelta)
        EngineExtensionRegistry.shared.fixedUpdateExtensions(deltaTime: plan.stepDelta, context: context)
        RenderExtensionRegistry.shared.fixedUpdateExtensions(deltaTime: plan.stepDelta, context: context)
        updateCustomSystems(deltaTime: plan.stepDelta)
    }
    return plan
}
