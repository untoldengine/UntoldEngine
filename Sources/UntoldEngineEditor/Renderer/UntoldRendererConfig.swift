//
//  UntoldRendererConfig.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 24/9/25.
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
