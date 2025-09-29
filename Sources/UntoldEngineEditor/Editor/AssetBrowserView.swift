//
//  AssetBrowserView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//
import SwiftUI
import UniformTypeIdentifiers
import UntoldEngine


enum AssetCategory: String, CaseIterable {
    case models = "Models"
    case materials = "Materials"
    case hdr = "HDR"
    case animations = "Animations"

    var iconName: String {
        switch self {
        case .models:
            return "cube.fill"
        case .animations:
            return "film"
        case .hdr:
            return "film"
        case .materials:
            return "film"
        }
    }
}

struct AssetBrowserView: View {
    @Binding var assets: [String: [Asset]]
    @Binding var selectedAsset: Asset?
    @State private var selectedCategory: String? = "Models" // Default category
    @State private var selectedAssetName: String?
    @ObservedObject var editorBaseAssetPath = EditorAssetBasePath.shared
    @ObservedObject var selectionManager: SelectionManager
    @State private var folderPathStack: [URL] = []
    var editor_addEntityWithAsset: () -> Void
    private var currentFolderPath: URL? {
        folderPathStack.last
    }

    var body: some View {
        ZStack {
            Color.editorBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                // MARK: - Top Bar

                HStack {
                    Text("Assets")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)

                    Button(action: importAsset) {
                        HStack(spacing: 6) {
                            Text("Import Asset")
                            Image(systemName: "plus.circle")
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // Set Base Path Button
                    Button(action: selectResourceDirectory) {
                        HStack(spacing: 6) {
                            Image(systemName: "externaldrive.fill.badge.plus")
                                .foregroundColor(.white)
                            Text("Set Path")
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                // MARK: - Path Indicator

                if let resourceDir = editorBaseAssetPath.basePath {
                    Text("Current Path: \(resourceDir.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 5)
                } else {
                    Text("No Path Selected")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 5)
                }

                // MARK: - Sidebar and Asset List Layout

                HStack(spacing: 8) {
                    // MARK: - Sidebar

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(AssetCategory.allCases, id: \.self) { category in
                                HStack {
                                    Image(systemName: selectedCategory == category.rawValue ? "folder.fill" : "folder")
                                        .foregroundColor(selectedCategory == category.rawValue ? .blue : .gray)
                                    Text(category.rawValue)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(selectedCategory == category.rawValue ? .blue : .primary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(selectedCategory == category.rawValue ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                                .onTapGesture {
                                    selectedCategory = category.rawValue // Use enum rawValue
                                    folderPathStack = [] // reset folder navigation when switching category
                                }
                            }
                        }
                        .padding(8)
                    }

                    .frame(width: 120)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)

                    // MARK: - Asset List

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let selectedCategory {
                                // Show breadcrumb if inside folders
                                if !folderPathStack.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 4) {
                                            Button("Assets") {
                                                folderPathStack = []
                                            }

                                            ForEach(Array(folderPathStack.enumerated()), id: \.element) { index, url in
                                                Text(">")
                                                Button(url.lastPathComponent) {
                                                    folderPathStack = Array(folderPathStack.prefix(upTo: index + 1))
                                                }
                                            }
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.05))
                                        .cornerRadius(6)
                                    }
                                }

                                // Show either folder contents or top-level categories
                                if let currentFolderPath {
                                    folderContentsView(for: currentFolderPath, selectionManager: selectionManager)
                                } else {
                                    if let categoryAssets = assets[selectedCategory] {
                                        ForEach(categoryAssets) { asset in
                                            assetRow(asset)
                                                .onTapGesture(count: 2) {
//                                                    if !asset.isFolder, selectedCategory == "HDR" {
//                                                        selectAsset(asset)
//                                                        addIBL(asset: asset)
//                                                    }
                                                }
                                                .onTapGesture(count: 1) {
                                                    if asset.isFolder {
                                                        folderPathStack.append(asset.path)
                                                    } else {
                                                        selectAsset(asset)
                                                    }
                                                }
                                        }
                                    } else {
                                        Text("No assets available")
                                            .foregroundColor(.gray)
                                            .padding()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(maxHeight: 300)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(8)
                }
                .frame(maxHeight: 300)
            }
            .padding(10)
        }
        .frame(maxHeight: 200)
        .onAppear(perform: loadAssets)
        .onChange(of: editorBaseAssetPath.basePath) {
            loadAssets()
        }
    }

    // MARK: - Select Resource Directory

    private func selectResourceDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selectedURL = panel.urls.first {
            assetBasePath = selectedURL
            EditorAssetBasePath.shared.basePath = assetBasePath
        }
    }

    private func importAsset() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [
            UTType(filenameExtension: "usdc")!,
            .png, .jpeg, .tiff,
            UTType(filenameExtension: "hdr")!
        ]
        openPanel.canChooseDirectories = (selectedCategory == "Materials")
        openPanel.allowsMultipleSelection = true

        guard let basePath = assetBasePath else { return }
        // Supported categories must match your enum/string values
        guard ["Models", "Animations", "HDR", "Materials"].contains(selectedCategory) else { return }

        let fm = FileManager.default
        let categoryRoot = basePath.appendingPathComponent(selectedCategory!, isDirectory: true)
        // Ensure category folder exists (e.g., <Base>/Models)
        try? fm.createDirectory(at: categoryRoot, withIntermediateDirectories: true)

        if openPanel.runModal() == .OK {
            for sourceURL in openPanel.urls {
                do {
                    switch selectedCategory {
                    case "HDR":
                        // Copy .hdr directly into HDR folder
                        let destURL = categoryRoot.appendingPathComponent(sourceURL.lastPathComponent)
                        if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
                        try fm.copyItem(at: sourceURL, to: destURL)

                    case "Materials":
                        if sourceURL.hasDirectoryPath {
                            // Copy entire material folder (recommended)
                            let destURL = categoryRoot.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: true)
                            if fm.fileExists(atPath: destURL.path) { try fm.removeItem(at: destURL) }
                            try fm.copyItem(at: sourceURL, to: destURL)
                        } else {
                            // Single texture fallback → create folder named after the file (without ext)
                            let baseName = sourceURL.deletingPathExtension().lastPathComponent
                            let materialFolder = categoryRoot.appendingPathComponent(baseName, isDirectory: true)
                            if fm.fileExists(atPath: materialFolder.path) { try fm.removeItem(at: materialFolder) }
                            try fm.createDirectory(at: materialFolder, withIntermediateDirectories: true)
                            let destFile = materialFolder.appendingPathComponent(sourceURL.lastPathComponent)
                            try fm.copyItem(at: sourceURL, to: destFile)
                        }

                    case "Models", "Animations":
                        // Create <Category>/<name>/ and copy the .usdc
                        let baseName = sourceURL.deletingPathExtension().lastPathComponent
                        let destFolder = categoryRoot.appendingPathComponent(baseName, isDirectory: true)
                        try fm.createDirectory(at: destFolder, withIntermediateDirectories: true)

                        let destModel = destFolder.appendingPathComponent(sourceURL.lastPathComponent)
                        if fm.fileExists(atPath: destModel.path) { try fm.removeItem(at: destModel) }
                        try fm.copyItem(at: sourceURL, to: destModel)

                        // For Models: also copy sibling "textures" folder if it exists
                        if selectedCategory == "Models" {
                            let textureFolderSource = sourceURL.deletingLastPathComponent().appendingPathComponent("textures", isDirectory: true)
                            let textureFolderDest = destFolder.appendingPathComponent("textures", isDirectory: true)
                            var isDir: ObjCBool = false
                            if fm.fileExists(atPath: textureFolderSource.path, isDirectory: &isDir), isDir.boolValue {
                                if fm.fileExists(atPath: textureFolderDest.path) { try fm.removeItem(at: textureFolderDest) }
                                try fm.copyItem(at: textureFolderSource, to: textureFolderDest)
                            }
                        }

                    default:
                        break
                    }
                } catch {
                    print("Error copying \(sourceURL.lastPathComponent): \(error)")
                }
            }

            loadAssets()
        }
    }

    // MARK: - Load Assets

    private func loadAssets() {
        guard let basePath = assetBasePath else { return }

        var groupedAssets: [String: [Asset]] = [:]

        for category in AssetCategory.allCases {
            // Flattened: <Base>/<Category> (no "Assets" root)
            let categoryPath = basePath.appendingPathComponent(category.rawValue, isDirectory: true)
            var categoryAssets: [Asset] = []

            if let contents = try? FileManager.default.contentsOfDirectory(
                at: categoryPath,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for item in contents {
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir) {
                        if isDir.boolValue {
                            // It’s a folder — valid for all categories
                            categoryAssets.append(Asset(name: item.lastPathComponent,
                                                        category: category.rawValue,
                                                        path: item,
                                                        isFolder: true))
                        } else if category == .hdr {
                            // For HDR, also allow .hdr files directly in the HDR folder
                            if item.pathExtension.lowercased() == "hdr" {
                                categoryAssets.append(Asset(name: item.lastPathComponent,
                                                            category: category.rawValue,
                                                            path: item,
                                                            isFolder: false))
                            }
                        }
                    }
                }
            }

            groupedAssets[category.rawValue] = categoryAssets
        }

        assets = groupedAssets
    }

    @ViewBuilder
    private func assetRow(_ asset: Asset) -> some View {
        HStack {
            Image(systemName: asset.isFolder ? "folder.fill" : "cube.fill")
                .foregroundColor(.gray)
            Text(asset.name)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            selectedAssetName == asset.name ? Color.secondary.opacity(0.1) : Color.clear
        )
        .cornerRadius(6)
    }

    @ViewBuilder
    private func folderContentsView(for folder: URL, selectionManager _: SelectionManager) -> some View {
        if let contents = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            let items = contents.compactMap { item -> Asset? in
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        return Asset(name: item.lastPathComponent, category: selectedCategory ?? "", path: item, isFolder: true)
                    } else {
                        let allowedExtensions: Set<String> = ["usdc", "png", "jpg", "hdr", "tif"]
                        guard allowedExtensions.contains(item.pathExtension) else { return nil }

                        return Asset(name: item.lastPathComponent,
                                     category: selectedCategory ?? "",
                                     path: item)
                    }
                }
                return nil
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { asset in
                    assetRow(asset)
                        .onTapGesture(count: 2) {
//                            if !asset.isFolder, asset.path.pathExtension == "usdc", selectedCategory == "Models" {
//                                selectAsset(asset)
//                                editor_addEntityWithAsset()
//                            }
//
//                            if !asset.isFolder, asset.path.pathExtension == "png" || asset.path.pathExtension == "jpg" || asset.path.pathExtension == "tif", selectedCategory == "Materials" {
//                                selectAsset(asset)
//                                loadTextureType(entityId: selectionManager.selectedEntity!, assetName: asset.name, path: asset.path)
//                            }
                        }
                        .onTapGesture(count: 1) {
                            if asset.isFolder {
                                folderPathStack.append(asset.path)
                            } else {
                                selectAsset(asset)
                            }
                        }
                }
            }
        } else {
            Text("Folder is empty or inaccessible.")
                .foregroundColor(.gray)
                .padding()
        }
    }

    // MARK: - Select Asset

    private func selectAsset(_ asset: Asset) {
        selectedAsset = asset
        selectedAssetName = asset.name
    }
}
