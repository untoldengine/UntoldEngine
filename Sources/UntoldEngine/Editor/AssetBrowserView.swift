//
//  AssetBrowserView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//

import SwiftUI

@available(macOS 13.0, *)
struct AssetBrowserView: View {
    @Binding var assets: [String: [Asset]]
    @Binding var selectedAsset: Asset?
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

                    Spacer()

                    // Nicer "Set Base Path" Button
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

                // MARK: - Asset List

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(assets.keys.sorted(), id: \.self) { category in
                            VStack(alignment: .leading, spacing: 4) {
                                // Category Name
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.yellow)
                                    Text(category)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.blue)
                                }
                                .padding(.top, 5)
                                .padding(.horizontal, 10)

                                // Asset List
                                ForEach(assets[category] ?? []) { asset in
                                    HStack {
                                        Image(systemName: "cube.fill")
                                            .foregroundColor(.gray)

                                        Text(asset.name)
                                            .font(.system(size: 14, weight: .regular, design: .monospaced))

                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(6)
                                    .onTapGesture {
                                        selectAsset(asset)
                                    }
                                    .onHover { isHovering in
                                        if isHovering {
                                            NSCursor.pointingHand.set()
                                        } else {
                                            NSCursor.arrow.set()
                                        }
                                    }
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
            .padding(10)
        }
        .frame(maxHeight: 180)
        .onAppear(perform: loadAssets)
        .onChange(of: basePath) { _ in
            loadAssets()
        }
    }

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

    private func loadAssets() {
        guard let basePath else { return }

        let categories = ["Models", "Animations", "Materials"] // Only relevant folders
        var groupedAssets: [String: [Asset]] = [:]

        for category in categories {
            var categoryPath = basePath.appendingPathComponent("Assets")
            categoryPath = categoryPath.appendingPathComponent(category)

            if let files = try? FileManager.default.contentsOfDirectory(at: categoryPath, includingPropertiesForKeys: nil) {
                let filteredAssets = files.compactMap { file -> Asset? in
                    guard file.pathExtension == "usdc" else { return nil }
                    return Asset(name: file.deletingPathExtension().lastPathComponent,
                                 category: category,
                                 path: file)
                }

                if !filteredAssets.isEmpty {
                    groupedAssets[category] = filteredAssets
                }
            }
        }
        assets = groupedAssets
    }

    private func selectAsset(_ asset: Asset) {
        selectedAsset = asset
        print("Selected asset: \(asset.name) from \(asset.category) with URL \(asset.path)")
    }
}

// struct AssetBrowserView: View {
//    @Binding var assets: [String: [Asset]]
//    @State private var basePath: URL? = nil // User-selected base path
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            HStack {
//                Text("Assets")
//                    .font(.headline)
//
//                Spacer()
//
//                // **Set Base Path Button**
//                Button(action: selectResourceDirectory) {
//                    Image(systemName: "folder")
//                        .foregroundColor(.blue)
//                }
//                .buttonStyle(PlainButtonStyle()) // Minimalist button
//            }
//            .padding(.bottom, 5)
//
//            // Show selected directory
//            if let resourceDir = basePath {
//                Text("Current Path: \(resourceDir.lastPathComponent)")
//                    .font(.caption)
//                    .foregroundColor(.gray)
//                    .padding(.bottom, 5)
//            } else {
//                Text("No Path Selected")
//                    .font(.caption)
//                    .foregroundColor(.red)
//                    .padding(.bottom, 5)
//            }
//
//            Divider() // Clean separation
//
//            // **Grouped Vertical List**
//            ScrollView(.vertical, showsIndicators: true) {
//                VStack(alignment: .leading, spacing: 5) {
//                    ForEach(assets.keys.sorted(), id: \.self) { category in
//                        VStack(alignment: .leading, spacing: 5) {
//                            Text(category) // Folder Name (Category)
//                                .font(.system(size: 14, weight: .bold, design: .monospaced))
//                                .foregroundColor(.blue)
//                                .padding(.top, 5)
//
//                            ForEach(assets[category] ?? []) { asset in
//                                Text(asset.name)
//                                    .font(.system(size: 14, weight: .regular, design: .monospaced))
//                                    .padding(.leading, 10) // Indent under category
//                                    .onTapGesture {
//                                        selectAsset(asset)
//                                    }
//                            }
//                        }
//                    }
//                }
//                .padding(.horizontal, 5)
//            }
//            .frame(maxHeight: 300) // Limit scrollable area
//        }
//        .padding(10)
//        .background(Color.black.opacity(0.05))
//        .cornerRadius(5)
//        .onAppear(perform: loadAssets) // Fetch assets on launch
//        .onChange(of: basePath) { _ in
//            loadAssets() // Reload assets when basePath changes
//        }
//    }
//
//    // **Set Base Path**
//    private func selectResourceDirectory() {
//        let panel = NSOpenPanel()
//        panel.canChooseFiles = false
//        panel.canChooseDirectories = true
//        panel.allowsMultipleSelection = false
//
//        if panel.runModal() == .OK, let selectedURL = panel.urls.first {
//            basePath = selectedURL
//        }
//    }
//
//    // **Load Only `.usd` Assets and Group by Category**
//    private func loadAssets() {
//        guard let basePath else { return }
//
//        let categories = ["Models", "Animations"] // Only relevant folders
//        var groupedAssets: [String: [Asset]] = [:]
//
//        for category in categories {
//            let categoryPath = basePath.appendingPathComponent(category)
//
//            if let files = try? FileManager.default.contentsOfDirectory(at: categoryPath, includingPropertiesForKeys: nil) {
//                let filteredAssets = files.compactMap { file -> Asset? in
//                    guard file.pathExtension == "usdc" else { return nil }
//                    return Asset(name: file.deletingPathExtension().lastPathComponent,
//                                 category: category,
//                                 path: file)
//                }
//
//                if !filteredAssets.isEmpty {
//                    groupedAssets[category] = filteredAssets
//                }
//            }
//        }
//        assets = groupedAssets
//    }
//
//    private func selectAsset(_ asset: Asset) {
//        print("Selected asset: \(asset.name) from \(asset.category)")
//        // Here you can integrate selection logic
//    }
// }
