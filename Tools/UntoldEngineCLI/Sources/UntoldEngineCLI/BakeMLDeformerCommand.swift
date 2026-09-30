//
//  BakeMLDeformerCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import Foundation
import UntoldEngine

struct BakeMLDeformerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bake-mldeformer",
        abstract: "Bake an ML deformer training set from the XPBD muscle simulation",
        discussion: """
        Plays the given animation clips (plus smooth random augmentations) through
        the volumetric muscle simulation of a rigged .untold and records the pose
        features and the skin deltas the muscles produce, every few frames, into
        <output>.json / <output>.features.f32 / <output>.deltas.f16. Train the
        network with scripts/train_mldeformer.py, which writes the .untoldml the
        runtime loads from next to the asset.

        The muscle rig comes from the asset's muscle table or --muscles (the same
        JSON untoldexplorer.py --muscles consumes).

        Example:
          untoldengine bake-mldeformer --untold Models/hero/hero.untold \\
            --clip Animations/hero_flex/hero_flex.untoldanim \\
            --muscles hero.muscles.json --output bake/hero --passes 8
          python3 scripts/train_mldeformer.py --dataset bake/hero \\
            --output Models/hero/hero.untoldml
        """
    )

    @Option(name: .long, help: "The rigged .untold asset")
    var untold: String

    @Option(name: .long, help: "Animation clip file(s) (.untoldanim); repeatable")
    var clip: [String] = []

    @Option(name: .long, help: "Muscle rig JSON (defaults to the asset's muscle table)")
    var muscles: String?

    @Option(name: .long, help: "Output base path (without extension)")
    var output: String

    @Option(name: .long, help: "Augmentation passes per clip")
    var passes: Int = 6

    @Option(name: .long, help: "Record a sample every N simulated frames")
    var every: Int = 4

    @Option(name: .long, help: "Settle frames before the first sample of a play")
    var settle: Int = 24

    @Option(name: .customLong("max-angle-degrees"), help: "Largest augmentation rotation per joint")
    var maxAngleDegrees: Float = 25

    @Option(name: .customLong("frame-rate"), help: "Simulation frame rate")
    var frameRate: Float = 90

    @Option(name: .long, help: "Random seed")
    var seed: UInt64 = 1

    func run() throws {
        let loader = NativeFormatLoader()
        let assetURL = URL(fileURLWithPath: untold)
        let asset = try loader.loadAssetSync(from: assetURL)

        var clips: [RuntimeAnimationClip] = []
        for path in clip {
            let clipAsset = try loader.loadAssetSync(from: URL(fileURLWithPath: path))
            clips.append(contentsOf: clipAsset.animationClips)
        }
        guard !clips.isEmpty else {
            throw ValidationError("No animation clips found; pass at least one --clip .untoldanim")
        }

        let rig: MuscleRig
        if let muscles {
            rig = try MuscleRig(contentsOf: URL(fileURLWithPath: muscles))
        } else if let assetRig = asset.nodes.first(where: { $0.skeleton?.muscleRig != nil })?.skeleton?.muscleRig {
            rig = assetRig
        } else {
            throw ValidationError("The asset has no muscle table; pass --muscles rig.json")
        }

        var options = MLDeformerBakeOptions()
        options.augmentationPasses = passes
        options.sampleEveryFrames = every
        options.settleFrames = settle
        options.maxAugmentationAngle = maxAngleDegrees * .pi / 180
        options.frameRate = frameRate
        options.seed = seed

        print("Baking \(asset.assetName): \(clips.count) clip(s), \(rig.muscles.count) muscles ...")
        let summary = try MLDeformerBaker.bake(
            asset: asset, clips: clips, rig: rig, options: options,
            outputBase: URL(fileURLWithPath: output)
        ) { message in
            print("  \(message)")
        }
        print("Samples: \(summary.sampleCount), features: \(summary.featureCount) (\(summary.jointPaths.count) joints), active vertices: \(summary.activeVertexCount)")
        print("Wrote \(summary.outputBase.path).json / .features.f32 / .deltas.f16")
    }
}
