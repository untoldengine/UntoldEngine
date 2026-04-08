//
//  DemoExportSheet.swift
//

#if os(macOS)
    import AppKit
    import SwiftUI
    import UniformTypeIdentifiers

    struct DemoExportSheet: View {
        @Bindable var state: DemoState
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(state.exportMode == .untoldAsset ? "Export To .untold" : "Export Tiled Scene")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(state.isExporting)
                }

                Text(descriptionText)
                    .foregroundStyle(.secondary)

                Picker("Mode", selection: $state.exportMode) {
                    ForEach(DemoState.ExportMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 10) {
                    pathRow(
                        title: "Source",
                        value: state.exportSourceURL?.path ?? "Choose a .usd/.usda/.usdc/.usdz file",
                        buttonTitle: "Choose…",
                        action: chooseSourceAsset
                    )

                    if state.exportMode == .untoldAsset {
                        pathRow(
                            title: "Output",
                            value: state.exportOutputURL?.path ?? "Choose an output .untold file",
                            buttonTitle: "Save As…",
                            action: chooseOutputAsset
                        )
                    } else {
                        pathRow(
                            title: "Output Folder",
                            value: state.exportTileOutputDirectoryURL?.path ?? "Choose an output directory for tile exports",
                            buttonTitle: "Choose…",
                            action: chooseTileOutputDirectory
                        )
                    }
                }

                Divider()

                if state.exportMode == .untoldAsset {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Source Orientation", selection: $state.exportSourceOrientation) {
                            ForEach(DemoState.ExportSourceOrientation.allCases) { orientation in
                                Text(orientation.title).tag(orientation)
                            }
                        }
                        .pickerStyle(.menu)

                        Toggle("Convert Orientation", isOn: $state.exportConvertOrientation)
                            .toggleStyle(.checkbox)

                        Toggle("Write Validation JSON", isOn: $state.exportValidateOutput)
                            .toggleStyle(.checkbox)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Auto Tile Size", isOn: $state.exportAutoTileSize)
                            .toggleStyle(.checkbox)

                        if !state.exportAutoTileSize {
                            tileSizeRow("Tile Size X", value: $state.exportTileSizeX)
                            tileSizeRow("Tile Size Y", value: $state.exportTileSizeY)
                            tileSizeRow("Tile Size Z", value: $state.exportTileSizeZ)
                        }

                        Toggle("Generate HLOD", isOn: $state.exportGenerateHLOD)
                            .toggleStyle(.checkbox)

                        Toggle("Generate LOD", isOn: $state.exportGenerateLOD)
                            .toggleStyle(.checkbox)
                    }
                }

                if let status = state.exportStatusMessage {
                    Text(status)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(state.exportDidSucceed ? .green : .red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Spacer()
                    if state.isExporting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("Export") {
                        state.beginUntoldExport()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canExport)
                }
            }
            .padding(20)
            .frame(width: 680)
        }

        private var descriptionText: String {
            switch state.exportMode {
            case .untoldAsset:
                "Convert a local USD/USDZ asset into UntoldEngine's runtime format using the existing exporter script."
            case .tiledScene:
                "Partition a local USD/USDZ scene into streaming tiles and generate a manifest JSON plus .untold tile payloads."
            }
        }

        private var canExport: Bool {
            if state.isExporting || state.exportSourceURL == nil {
                return false
            }

            switch state.exportMode {
            case .untoldAsset:
                return state.exportOutputURL != nil
            case .tiledScene:
                return state.exportTileOutputDirectoryURL != nil
            }
        }

        private func pathRow(title: String, value: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.caption, design: .default).weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 10) {
                    Text(value)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                    Button(buttonTitle, action: action)
                        .buttonStyle(.bordered)
                        .disabled(state.isExporting)
                }
            }
        }

        private func chooseSourceAsset() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [
                UTType(filenameExtension: "usd") ?? .data,
                UTType(filenameExtension: "usda") ?? .data,
                UTType(filenameExtension: "usdc") ?? .data,
                UTType(filenameExtension: "usdz") ?? .data,
            ]

            if panel.runModal() == .OK {
                state.exportSourceURL = panel.url

                if state.exportOutputURL == nil, let sourceURL = panel.url {
                    state.exportOutputURL = sourceURL
                        .deletingPathExtension()
                        .appendingPathExtension("untold")
                }
            }
        }

        private func chooseOutputAsset() {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: "untold") ?? .data]
            panel.nameFieldStringValue = suggestedOutputFilename()

            if panel.runModal() == .OK {
                state.exportOutputURL = panel.url
            }
        }

        private func chooseTileOutputDirectory() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false

            if panel.runModal() == .OK {
                state.exportTileOutputDirectoryURL = panel.url
            }
        }

        private func tileSizeRow(_ title: String, value: Binding<Double>) -> some View {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("", value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
            }
        }

        private func suggestedOutputFilename() -> String {
            if let outputURL = state.exportOutputURL {
                return outputURL.lastPathComponent
            }

            if let sourceURL = state.exportSourceURL {
                return sourceURL.deletingPathExtension().lastPathComponent + ".untold"
            }

            return "asset.untold"
        }
    }
#endif
