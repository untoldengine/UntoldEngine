//
//  UntoldRendererConfig.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import UntoldEngine

extension UntoldRendererConfig {
    public static var editor: UntoldRendererConfig {
        return UntoldRendererConfig(
            initPipelineBlocks: EditorDefaultPipeLines(),
            updateRenderingSystemCallback: EditorUpdateRenderingSystem
        )
    }
}
