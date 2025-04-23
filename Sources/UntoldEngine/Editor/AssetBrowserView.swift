//
//  AssetBrowserView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import SwiftUI

enum AssetCategory: String, CaseIterable {
    case models = "Models"
    case animations = "Animations"

    var iconName: String {
        switch self {
        case .models:
            return "cube.fill"
        case .animations:
            return "film"
        }
    }
}

struct AssetBrowserView: View {
    @Binding var assets: [String: [Asset]]
    @Binding var selectedAsset: Asset?
    @State private var selectedCategory: String? = "Models" // Default category
    @State private var selectedAssetName: String?
    @State private var basePath: URL? = nil
    // @State private var currentFolderPath: URL? = nil
    @State private var folderPathStack: [URL] = []

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

                if let resourceDir = basePath {
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
                                if let currentFolderPath = currentFolderPath {
                                    folderContentsView(for: currentFolderPath)
                                } else {
                                    if let categoryAssets = assets[selectedCategory] {
                                        ForEach(categoryAssets) { asset in
                                            assetRow(asset)
                                                .onTapGesture {
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
        .onChange(of: basePath) { _ in
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
            basePath = selectedURL
        }
    }

    private func importAsset() {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["usdc", "png"]
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true

        guard let path = assetBasePath else {
            return
        }

        if openPanel.runModal() == .OK, let sourceURL = openPanel.url {
            let fileManager = FileManager.default

            var destinationURL = path.appendingPathComponent("Assets")

            if selectedCategory == "Models" {
                destinationURL = destinationURL.appendingPathComponent("Models")

            } else if selectedCategory == "Animations" {
                destinationURL = destinationURL.appendingPathComponent("Animations")
            }

            // if this is a model, make a subfolder using the base name
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let modelFolder = destinationURL.appendingPathComponent(baseName)

            do {
                // Create Model folder
                if !fileManager.fileExists(atPath: modelFolder.path) {
                    try fileManager.createDirectory(at: modelFolder, withIntermediateDirectories: true)
                }

                // copy usdc file
                let finalModelPath = modelFolder.appendingPathComponent(sourceURL.lastPathComponent)

                if !fileManager.fileExists(atPath: finalModelPath.path) {
                    try fileManager.copyItem(at: sourceURL, to: finalModelPath)
                }

                // copy texture folder
                if selectedCategory == "Models" {
                    let textureFolderSource = sourceURL.deletingLastPathComponent().appendingPathComponent("textures")
                    let textureFolderDest = modelFolder.appendingPathComponent("textures")

                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: textureFolderSource.path, isDirectory: &isDir), isDir.boolValue {
                        if !fileManager.fileExists(atPath: textureFolderDest.path) {
                            try fileManager.copyItem(at: textureFolderSource, to: textureFolderDest)
                        }
                    }
                }

                loadAssets()
            } catch {
                print("Error copying file: \(error)")
            }
        }
    }

    // MARK: - Load Assets

    private func loadAssets() {
        guard let assetBasePath else { return }

        basePath = assetBasePath

        var groupedAssets: [String: [Asset]] = [:]

        for category in AssetCategory.allCases {
            var categoryPath = basePath!.appendingPathComponent("Assets")
            categoryPath = categoryPath.appendingPathComponent(category.rawValue)

            if let folders = try? FileManager.default.contentsOfDirectory(at: categoryPath, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                let folderAssets = folders.compactMap { folder -> Asset? in
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
                        return nil
                    }

                    return Asset(name: folder.lastPathComponent, category: category.rawValue, path: folder, isFolder: true)
                }
                groupedAssets[category.rawValue] = folderAssets
            }
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
    private func folderContentsView(for folder: URL) -> some View {
        if let contents = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            let items = contents.compactMap { item -> Asset? in
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        return Asset(name: item.lastPathComponent, category: selectedCategory ?? "", path: item, isFolder: true)
                    } else {
                        let allowedExtensions: Set<String> = ["usdc", "obj", "png"]
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
                        .onTapGesture {
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
