//
//  EditorLightingSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import UntoldEngine

func loadLightDebugMeshes() {
    spotLightDebugMesh = loadRawMesh(name: "spot_light_debug_mesh", filename: "spot_light_debug_mesh", withExtension: "usdc")

    pointLightDebugMesh = loadRawMesh(name: "point_light_debug_mesh", filename: "point_light_debug_mesh", withExtension: "usdc")

    areaLightDebugMesh = loadRawMesh(name: "area_light_debug_mesh", filename: "area_light_debug_mesh", withExtension: "usdc")

    dirLightDebugMesh = loadRawMesh(name: "dir_light_debug_mesh", filename: "dir_light_debug_mesh", withExtension: "usdc")
}
