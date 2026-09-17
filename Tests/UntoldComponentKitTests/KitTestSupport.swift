//
//  KitTestSupport.swift
//  UntoldComponentKitTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldComponentKit
@testable import UntoldEngine
import XCTest

/// Gives every test a clean engine and a freshly installed kit.
@MainActor func resetKitTestState() {
    scene = Scene()
    entityNameMap.removeAll()
    reverseEntityNameMap.removeAll()
    globalEntityCounter = 0
    needsFinalizeDestroys = false
    hasPendingDestroys = false
    gameMode = false
    EngineExtensionRegistry.shared.removeAll()
    EntityLifecycleEvents.shared.reset()
    OctreeSystem.shared.clear()
    CodeComponentRegistry.shared.removeAll()
    EditorExtensionRegistry.shared.removeAll()
    EntityTemplateRegistry.shared.removeAll()
    CodeComponentSystem.install()
}

func makeKitTestContext(frameIndex: UInt64 = 1) -> EngineExtensionUpdateContext {
    EngineExtensionUpdateContext(
        viewport: SIMD2<Int>(640, 480),
        immersionStyle: .none,
        frameIndex: frameIndex,
        currentEye: 0,
        isPrimaryEye: true
    )
}

// MARK: - Component doubles

final class SpinnerComponent: CodeComponent {
    enum Stance: String, CaseIterable { case idle, walk, run }

    @UntoldAttribute("Speed", range: 0 ... 20, step: 0.5) var speed: Float = 5
    @UntoldAttribute var lives: Int = 3
    @UntoldAttribute var invincible = false
    @UntoldAttribute var nickname: String = "spinner"
    @UntoldAttribute(.multiline) var notes: String = "hello"
    @UntoldAttribute var spawnOffset: SIMD3<Float> = [0, 1, 0]
    @UntoldAttribute(.color) var tint: SIMD4<Float> = [1, 1, 1, 1]
    @UntoldAttribute var target = EntityRef()
    @UntoldAttribute var clip = AssetRef(category: .animations)
    @UntoldAttribute var stance: Stance = .idle

    var runtimeOnly = 42
    var events: [String] = []

    override class var actions: [ComponentAction] {
        [ComponentAction("Jump") { ($0 as? SpinnerComponent)?.events.append("jump") }]
    }

    override func onAttach() {
        events.append("attach")
    }

    override func onStart() {
        events.append("start")
    }

    override func onUpdate(deltaTime: Float) {
        events.append("update:\(deltaTime)")
    }

    override func onFixedUpdate(deltaTime: Float) {
        events.append("fixed:\(deltaTime)")
    }

    override func onStop() {
        events.append("stop")
    }

    override func onDetach() {
        events.append("detach")
    }

    override func onEditorChanged(property: String) {
        events.append("edited:\(property)")
    }
}

class BaseMover: CodeComponent {
    @UntoldAttribute var baseSpeed: Float = 1
}

final class DerivedMover: BaseMover {
    @UntoldAttribute var boost: Int = 2
}

/// Two different types that share one type name, the way two revisions of a library do.
enum RevisionA {
    final class Reloadable: CodeComponent {
        @UntoldAttribute var speed: Float = 1
        @UntoldAttribute var legacy: Int = 7
        var detached = false
        override func onDetach() {
            detached = true
        }
    }
}

enum RevisionB {
    final class Reloadable: CodeComponent {
        @UntoldAttribute var speed: Float = 1
        @UntoldAttribute var fresh = true
    }
}

// MARK: - Extension doubles

final class SampleExtension: EditorExtension {
    enum BlendCap: String, CaseIterable, UntoldMenuTitled {
        case c64 = "64"
        case c128 = "128"
        case unlimited

        var menuTitle: String {
            self == .unlimited ? "Unlimited" : rawValue
        }
    }

    @UntoldMenu(.view, "Preview Twins", tooltip: "Swap meshes for their splat twins") var preview = true
    @UntoldMenu(.debug, " Splat Twin / Blend Cap ") var blendCap: BlendCap = .c64
    @UntoldMenu(.debug, "Splat Twin/Reset", key: "r")
    var reset = UntoldMenuAction { (owner: EditorExtension) in (owner as? SampleExtension)?.resetCount += 1 }
    @UntoldMenu(.tools, "Bake", persist: false, enabled: { false }) var bake = false

    var resetCount = 0
}

final class BrokenExtension: EditorExtension {
    @UntoldMenu(.debug, " / ") var untitled = false
    @UntoldMenu(.debug, "Splat Twin/Same") var first = false
    @UntoldMenu(.debug, "Splat Twin / Same") var second = false
}

// MARK: - Entity template doubles

/// Editor-only representation: an icon in the viewport, nothing in a game.
final class MarkerComponent: CodeComponent {
    @UntoldAttribute var team: Int = 1

    override var editorRepresentation: EditorRepresentation {
        .icon(systemImage: "flag.fill", tint: team == 1 ? SIMD3<Float>(0.2, 0.8, 0.4) : SIMD3<Float>(0.9, 0.3, 0.3))
    }
}

final class MarkerEntityTemplate: EntityTemplate {
    override class var systemImage: String {
        "flag"
    }

    override func build(_ entity: EntityID) {
        add(MarkerComponent.self, to: entity)?.team = 7
    }
}

/// No representation at all, on the lights shelf to exercise shelf filtering.
final class RulesTemplate: EntityTemplate {
    override class var displayName: String {
        "Game Rules"
    }

    override class var shelf: UntoldEntityShelf {
        .lights
    }

    override func build(_ entity: EntityID) {
        add(SpinnerComponent.self, to: entity)
    }
}
