//
//  Globals.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 29/9/25.
//
import Foundation
import UntoldEngine


var editorController: EditorController?

var visualDebug: Bool = false
var hotReload: Bool = false

var selectionDelegate: SelectionDelegate?

// Gizmo active
var gizmoActive: Bool = false
var activeHitGizmoEntity: EntityID = .invalid
var parentEntityIdGizmo: EntityID = .invalid

let gizmoDesiredScreenSize: Float = 500.0 // pixels

var spawnDistance: Float = 2.0

var accelStructResources = AccelStructResources()

var rayModelIntersectPipeline = ComputePipeline()

// Visual Debugger
enum DebugSelection: Int {
    case normalOutput
    case iblOutput
}

var currentDebugSelection: DebugSelection = .normalOutput

// light debug meshes
var spotLightDebugMesh: [Mesh] = []
var pointLightDebugMesh: [Mesh] = []
var areaLightDebugMesh: [Mesh] = []
var dirLightDebugMesh: [Mesh] = []

class DebugSettings: ObservableObject {
    static let shared = DebugSettings()

    @Published var selectedName: String = ""
    @Published var debugEnabled: Bool = true
}

// Editor
public var enableEditor: Bool = true

