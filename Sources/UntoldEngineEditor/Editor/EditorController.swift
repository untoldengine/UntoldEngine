//
//  EditorController.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 29/9/25.
//
import Foundation
import AppKit
import UniformTypeIdentifiers
import UntoldEngine
import simd


public class EditorComponentsState: ObservableObject {
    public static let shared = EditorComponentsState()

    @Published public var components: [EntityID: [ObjectIdentifier: ComponentOption_Editor]] = [:]

    func clear() {
        components.removeAll()
    }
}

public class EditorAssetBasePath: ObservableObject {
    public static let shared = EditorAssetBasePath()

    @Published public var basePath: URL? = assetBasePath
}

class EditorController: SelectionDelegate, ObservableObject {
    let selectionManager: SelectionManager
    var isEnabled: Bool = false
    @Published var activeMode: TransformManipulationMode = .none
    @Published var activeAxis: TransformAxis = .none

    init(selectionManager: SelectionManager) {
        self.selectionManager = selectionManager
        selectionDelegate = self
        isEnabled = true
        
        gameMode = false
    }

    func didSelectEntity(_ entityId: EntityID) {
        DispatchQueue.main.async {
            self.selectionManager.selectEntity(entityId: entityId)
        }
    }

    func resetActiveAxis() {
        activeAxis = .none
    }

    func refreshInspector() {
        DispatchQueue.main.async {
            self.selectionManager.objectWillChange.send()
        }
    }
}

func saveScene(sceneData: SceneData) {
    let savePanel = NSSavePanel()
    savePanel.title = "Save Scene"
    savePanel.allowedContentTypes = [UTType.json]
    savePanel.nameFieldStringValue = "untitled.json"
    savePanel.canCreateDirectories = true
    savePanel.isExtensionHidden = false

    savePanel.begin { result in
        if result == .OK, let url = savePanel.url {
            do {
                let encoder = JSONEncoder()

                encoder.outputFormatting = .prettyPrinted

                let jsonData = try encoder.encode(sceneData)
                try jsonData.write(to: url)
                print("Scene saved to \(url.path)")
            } catch {
                print("Failed to save scene: \(error)")
            }
        }
    }
}

func loadGameScene() -> SceneData? {
    let openPanel = NSOpenPanel()
    openPanel.title = "Open Scene"
    openPanel.allowedContentTypes = [UTType.json]
    openPanel.allowsMultipleSelection = false

    if openPanel.runModal() == .OK, let url = openPanel.url {
        let decoder = JSONDecoder()

        do {
            let jsonData = try Data(contentsOf: url)
            let sceneData = try decoder.decode(SceneData.self, from: jsonData)
            
            EditorAssetBasePath.shared.basePath = assetBasePath
            
            Logger.log(message: "Scene loaded from \(url.path)")
            return sceneData
        } catch {
            Logger.log(message: "Failed to load scene: \(error)")
        }
    }

    return nil
}
