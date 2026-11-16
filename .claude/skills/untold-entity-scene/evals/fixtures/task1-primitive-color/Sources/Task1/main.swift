import UntoldEngine

// Fixed harness. Do not edit.
//
// This task touches mesh/material creation, which requires a live Metal
// device (renderInfo.device) that only exists once the engine's renderer is
// bootstrapped (UntoldRenderer.create() + a view) - not available in a bare
// command-line target. So this harness is build-only: a successful `swift
// build` proves GameScene.swift compiles against the real API. Correctness
// of the calls (right entity name, right color, right position) is graded
// by reading the source against evals/task_evals.json's checklist, not by
// executing buildScene() here.

print("build-only harness: do not invoke buildScene() at runtime")
