//
//  AssetBrowserView.swift
//
//
//  Created by Harold Serrano on 2/19/25.
//
import AppKit
import SwiftUI

@available(macOS 12.0, *)
struct AssetBrowserView: View {
    @Binding var assets: [String: [Asset]]
    @State private var basePath: URL? = nil // User-selected base path

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Assets")
                    .font(.headline)

                Spacer()

                // **Set Base Path Button**
                Button(action: selectResourceDirectory) {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle()) // Minimalist button
            }
            .padding(.bottom, 5)

            // Show selected directory
            if let resourceDir = basePath {
                Text("Current Path: \(resourceDir.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 5)
            } else {
                Text("No Path Selected")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom, 5)
            }

            Divider() // Clean separation

            // **Grouped Vertical List**
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(assets.keys.sorted(), id: \.self) { category in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(category) // Folder Name (Category)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding(.top, 5)

                            ForEach(assets[category] ?? []) { asset in
                                Text(asset.name)
                                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                                    .padding(.leading, 10) // Indent under category
                                    .onTapGesture {
                                        selectAsset(asset)
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
            .frame(maxHeight: 300) // Limit scrollable area
        }
        .padding(10)
        .background(Color.black.opacity(0.05))
        .cornerRadius(5)
        .onAppear(perform: loadAssets) // Fetch assets on launch
        .onChange(of: basePath) { _ in
            loadAssets() // Reload assets when basePath changes
        }
    }

    // **Set Base Path**
    private func selectResourceDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selectedURL = panel.urls.first {
            basePath = selectedURL
        }
    }

    // **Load Only `.usd` Assets and Group by Category**
    private func loadAssets() {
        guard let basePath else { return }

        let categories = ["Models", "Animations"] // Only relevant folders
        var groupedAssets: [String: [Asset]] = [:]

        for category in categories {
            let categoryPath = basePath.appendingPathComponent(category)

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
        print("Selected asset: \(asset.name) from \(asset.category)")
        // Here you can integrate selection logic
    }
}
