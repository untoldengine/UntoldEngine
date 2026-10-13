//
//  GPUPassTiming.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import QuartzCore

/// GPU time per pass, measured by the GPU itself. A frame's passes write timestamps into a
/// counter sample buffer the frame's command buffer carries: a render pass at the start and
/// end of its vertex stage and of its fragment stage, a compute or blit pass at its bounds.
/// The buffer is resolved when the command buffer completes, and each pass's time is averaged
/// over the recent frames (the same label twice in a frame, one per eye, is summed). Off by
/// default: `setRendering(.gpuPassTiming(.enabled))`. Nothing is measured on a GPU without
/// stage-boundary sampling, and `averages()` stays empty.
public final class GPUPassTiming: @unchecked Sendable {
    public static let shared = GPUPassTiming()

    /// One pass's time per frame, in milliseconds: a render pass's vertex and fragment stages;
    /// a compute or blit pass has only `fragmentMs`, the whole pass.
    public struct PassTime: Sendable, Equatable {
        public let label: String
        public let vertexMs: Double
        public let fragmentMs: Double
        public var totalMs: Double { vertexMs + fragmentMs }
    }

    /// Samples per frame the buffer holds: four per render pass, two per compute or blit pass.
    private static let samplesPerFrame = 512
    /// Frames in flight whose buffers may still be unresolved.
    private static let ringSize = 4
    /// The weight of a new frame in the averages.
    private static let smoothing = 0.1

    private struct Pass {
        let label: String
        let firstSample: Int
        let isRenderPass: Bool
    }

    private struct Frame {
        let buffer: MTLCounterSampleBuffer
        var nextSample = 0
        var passes: [Pass] = []
        var inFlight = false
    }

    private let lock = NSLock()
    private var enabledFlag = false
    private var ring: [Frame] = []
    private var encoding: Int? // the ring slot of the frame being encoded
    private var averageTimes: [String: (vertex: Double, fragment: Double)] = [:]
    private var lastFrameTimes: [String: (vertex: Double, fragment: Double)] = [:]
    private var lastFrameIndex = 0
    private var warnedUnsupported = false

    // GPU ticks to seconds, from two readings of the device's clocks far enough apart.
    private var calibrationStart: (media: Double, gpu: MTLTimestamp)?
    private var secondsPerTick: Double?

    private init() {}

    /// Whether passes are being timed.
    public var isEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return enabledFlag
    }

    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        enabledFlag = enabled
        if !enabled {
            averageTimes = [:]
            lastFrameTimes = [:]
            encoding = nil
        }
        lock.unlock()
    }

    /// The last resolved frame's passes, heaviest first, with a number that changes with each
    /// resolved frame, for a caller that averages frames its own way. Empty when off.
    public func lastFrame() -> (index: Int, passes: [PassTime]) {
        lock.lock()
        defer { lock.unlock() }
        let passes = lastFrameTimes
            .map { PassTime(label: $0.key, vertexMs: $0.value.vertex, fragmentMs: $0.value.fragment) }
            .sorted { $0.totalMs > $1.totalMs }
        return (lastFrameIndex, passes)
    }

    /// Each pass's average time over the recent frames, heaviest first. Empty when off.
    public func averages() -> [PassTime] {
        lock.lock()
        defer { lock.unlock() }
        return averageTimes
            .map { PassTime(label: $0.key, vertexMs: $0.value.vertex, fragmentMs: $0.value.fragment) }
            .sorted { $0.totalMs > $1.totalMs }
    }

    // MARK: - Frame

    /// Starts timing a frame's passes: the frame's command buffer has just been created.
    public func beginFrame(device: MTLDevice) {
        lock.lock()
        defer { lock.unlock() }
        encoding = nil
        guard enabledFlag else { return }
        if ring.isEmpty, !makeRing(device: device) { return }
        calibrate(device: device)
        guard let slot = ring.indices.first(where: { !ring[$0].inFlight }) else { return }
        ring[slot].nextSample = 0
        ring[slot].passes = []
        encoding = slot
    }

    /// Ends the frame: the command buffer resolves the timestamps when it completes.
    public func endFrame(_ commandBuffer: MTLCommandBuffer) {
        lock.lock()
        guard let slot = encoding, !ring[slot].passes.isEmpty else {
            encoding = nil
            lock.unlock()
            return
        }
        encoding = nil
        ring[slot].inFlight = true
        let frame = ring[slot]
        lock.unlock()
        commandBuffer.addCompletedHandler { [weak self] cb in
            self?.resolve(frame, slot: slot, gpuSeconds: cb.gpuEndTime - cb.gpuStartTime)
        }
    }

    // MARK: - Passes

    /// Times a render pass about to be encoded with this descriptor: its vertex and fragment
    /// stages. The same label in one frame (one pass per eye) adds up.
    public func attach(_ descriptor: MTLRenderPassDescriptor, _ label: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let slot = encoding, ring[slot].nextSample + 4 <= Self.samplesPerFrame else { return }
        let first = ring[slot].nextSample
        guard let attachment = descriptor.sampleBufferAttachments[0] else { return }
        attachment.sampleBuffer = ring[slot].buffer
        attachment.startOfVertexSampleIndex = first
        attachment.endOfVertexSampleIndex = first + 1
        attachment.startOfFragmentSampleIndex = first + 2
        attachment.endOfFragmentSampleIndex = first + 3
        ring[slot].passes.append(Pass(label: label, firstSample: first, isRenderPass: true))
        ring[slot].nextSample += 4
    }

    /// A compute encoder for this command buffer, timed as a whole under `label` when the
    /// frame is being timed; a plain encoder otherwise.
    public func makeComputeEncoder(_ commandBuffer: MTLCommandBuffer, _ label: String) -> MTLComputeCommandEncoder? {
        lock.lock()
        guard let slot = encoding, ring[slot].nextSample + 2 <= Self.samplesPerFrame else {
            lock.unlock()
            return commandBuffer.makeComputeCommandEncoder()
        }
        let first = ring[slot].nextSample
        let descriptor = MTLComputePassDescriptor()
        guard let attachment = descriptor.sampleBufferAttachments[0] else {
            lock.unlock()
            return commandBuffer.makeComputeCommandEncoder()
        }
        attachment.sampleBuffer = ring[slot].buffer
        attachment.startOfEncoderSampleIndex = first
        attachment.endOfEncoderSampleIndex = first + 1
        ring[slot].passes.append(Pass(label: label, firstSample: first, isRenderPass: false))
        ring[slot].nextSample += 2
        lock.unlock()
        return commandBuffer.makeComputeCommandEncoder(descriptor: descriptor)
    }

    /// A blit encoder for this command buffer, timed as a whole under `label` when the frame
    /// is being timed; a plain encoder otherwise.
    public func makeBlitEncoder(_ commandBuffer: MTLCommandBuffer, _ label: String) -> MTLBlitCommandEncoder? {
        lock.lock()
        guard let slot = encoding, ring[slot].nextSample + 2 <= Self.samplesPerFrame else {
            lock.unlock()
            return commandBuffer.makeBlitCommandEncoder()
        }
        let first = ring[slot].nextSample
        let descriptor = MTLBlitPassDescriptor()
        guard let attachment = descriptor.sampleBufferAttachments[0] else {
            lock.unlock()
            return commandBuffer.makeBlitCommandEncoder()
        }
        attachment.sampleBuffer = ring[slot].buffer
        attachment.startOfEncoderSampleIndex = first
        attachment.endOfEncoderSampleIndex = first + 1
        ring[slot].passes.append(Pass(label: label, firstSample: first, isRenderPass: false))
        ring[slot].nextSample += 2
        lock.unlock()
        return commandBuffer.makeBlitCommandEncoder(descriptor: descriptor)
    }

    // MARK: - Resolution

    private func makeRing(device: MTLDevice) -> Bool {
        guard device.supportsCounterSampling(.atStageBoundary),
              let counterSet = device.counterSets?.first(where: { $0.name == MTLCommonCounterSet.timestamp.rawValue })
        else {
            if !warnedUnsupported {
                warnedUnsupported = true
                Logger.logWarning(message: "GPU pass timing: this GPU does not sample timestamps at stage boundaries; passes are not timed")
            }
            enabledFlag = false
            return false
        }
        let descriptor = MTLCounterSampleBufferDescriptor()
        descriptor.counterSet = counterSet
        descriptor.storageMode = .shared
        descriptor.sampleCount = Self.samplesPerFrame
        descriptor.label = "GPU pass timing"
        var frames: [Frame] = []
        for _ in 0 ..< Self.ringSize {
            guard let buffer = try? device.makeCounterSampleBuffer(descriptor: descriptor) else {
                Logger.logWarning(message: "GPU pass timing: no counter sample buffer; passes are not timed")
                enabledFlag = false
                return false
            }
            frames.append(Frame(buffer: buffer))
        }
        ring = frames
        return true
    }

    /// The GPU clock against the media clock, read once at the start and again after a
    /// quarter of a second: GPU timestamps come in ticks whose length the device does not say.
    private func calibrate(device: MTLDevice) {
        guard secondsPerTick == nil else { return }
        let gpu = device.sampleTimestamps().gpu
        let media = CACurrentMediaTime()
        guard let start = calibrationStart else {
            calibrationStart = (media, gpu)
            return
        }
        let elapsed = media - start.media
        guard elapsed >= 0.25, gpu > start.gpu else { return }
        secondsPerTick = elapsed / Double(gpu - start.gpu)
    }

    private func resolve(_ frame: Frame, slot: Int, gpuSeconds: Double) {
        defer {
            lock.lock()
            if slot < ring.count { ring[slot].inFlight = false }
            lock.unlock()
        }
        guard frame.nextSample > 0,
              let data = try? frame.buffer.resolveCounterRange(0 ..< frame.nextSample)
        else { return }
        let stamps: [UInt64] = data.withUnsafeBytes { bytes in
            let results = bytes.bindMemory(to: MTLCounterResultTimestamp.self)
            return results.map(\.timestamp)
        }
        guard stamps.count >= frame.nextSample else { return }

        lock.lock()
        let secondsPerTick = self.secondsPerTick
        lock.unlock()
        // Until the clocks are calibrated, the frame's own span sets the scale.
        let valid = stamps.filter { $0 != MTLCounterErrorValue && $0 != 0 }
        guard let first = valid.min(), let last = valid.max(), last > first else { return }
        let msPerTick = (secondsPerTick ?? (gpuSeconds / Double(last - first))) * 1000.0

        func span(_ start: Int, _ end: Int) -> Double {
            let a = stamps[start], b = stamps[end]
            guard a != MTLCounterErrorValue, b != MTLCounterErrorValue, a != 0, b != 0, b >= a else { return 0 }
            return Double(b - a) * msPerTick
        }
        var frameTimes: [String: (vertex: Double, fragment: Double)] = [:]
        for pass in frame.passes {
            let vertex = pass.isRenderPass ? span(pass.firstSample, pass.firstSample + 1) : 0
            let fragment = pass.isRenderPass
                ? span(pass.firstSample + 2, pass.firstSample + 3)
                : span(pass.firstSample, pass.firstSample + 1)
            let before = frameTimes[pass.label] ?? (0, 0)
            frameTimes[pass.label] = (before.vertex + vertex, before.fragment + fragment)
        }

        lock.lock()
        guard enabledFlag else {
            lock.unlock()
            return
        }
        lastFrameTimes = frameTimes
        lastFrameIndex &+= 1
        let weight = Self.smoothing
        for label in Set(averageTimes.keys).union(frameTimes.keys) {
            let now = frameTimes[label] ?? (0, 0)
            guard let old = averageTimes[label] else {
                averageTimes[label] = now
                continue
            }
            averageTimes[label] = (old.vertex + (now.vertex - old.vertex) * weight,
                               old.fragment + (now.fragment - old.fragment) * weight)
        }
        lock.unlock()
    }
}
