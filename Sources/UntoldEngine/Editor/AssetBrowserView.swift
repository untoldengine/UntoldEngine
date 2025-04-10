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
    case materials = "Materials"

    var iconName: String {
        switch self {
        case .models:
            return "cube.fill"
        case .animations:
            return "film"
        case .materials:
            return "paintpalette"
        }
    }
}

@available(macOS 13.0, *)
struct AssetBrowserView: View {
    @Binding var assets: [String: [Asset]]
    @Binding var selectedAsset: Asset?
    @State private var selectedCategory: String? = "Models" // Default category
    @State private var selectedAssetName: String?
    @State private var basePath: URL? = nil

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
                            if let selectedCategory, let categoryAssets = assets[selectedCategory] {
                                ForEach(categoryAssets) { asset in
                                    HStack {
                                        Image(systemName: "cube.fill")
                                            .foregroundColor(.gray)
                                        let assetName: String = asset.name + "." + asset.path.pathExtension
                                        Text(assetName)
                                            .font(.system(size: 14, weight: .regular, design: .monospaced))

                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        selectedAssetName == asset.name ? Color.secondary.opacity(0.1) : Color.clear
                                    )
                                    .cornerRadius(6)
                                    .onTapGesture {
                                        selectAsset(asset)
                                    }
                                }
                            } else {
                                Text("No assets available")
                                    .foregroundColor(.gray)
                                    .padding()
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
        openPanel.allowedFileTypes = ["usdc", "obj", "png"]
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

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

            } else if selectedCategory == "Materials" {
                destinationURL = destinationURL.appendingPathComponent("Materials")
            }

            destinationURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)

            if !fileManager.fileExists(atPath: destinationURL.path) {
                do {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    loadAssets()
                } catch {
                    print("Error copying file: \(error)")
                }
            } else {
                print("File already exists at destination.")
            }

            // Optional: trigger model reload or update Asset Browser list here
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

            if let files = try? FileManager.default.contentsOfDirectory(at: categoryPath, includingPropertiesForKeys: nil) {
                let filteredAssets = files.compactMap { file -> Asset? in
                    let allowedExtensions: Set<String> = ["usdc", "obj", "png"]
                    guard allowedExtensions.contains(file.pathExtension) else { return nil }
                    return Asset(name: file.deletingPathExtension().lastPathComponent,
                                 category: category.rawValue, // Use enum rawValue
                                 path: file)
                }

                if !filteredAssets.isEmpty {
                    groupedAssets[category.rawValue] = filteredAssets
                }
            }
        }
        assets = groupedAssets
    }

    // MARK: - Select Asset

    private func selectAsset(_ asset: Asset) {
        selectedAsset = asset
        selectedAssetName = asset.name
    }
}
