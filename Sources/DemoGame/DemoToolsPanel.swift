//
//  DemoToolsPanel.swift
//

#if os(macOS)
    import SwiftUI

    struct DemoToolsPanel: View {
        let isBusy: Bool
        let isExporting: Bool
        let openExportSheet: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tools")
                    .font(.headline)

                Divider()

                Text("Convert USD to Engine Runtime Asset.")
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(.secondary)

                Button(isExporting ? "Exporting..." : "Export Asset") {
                    openExportSheet()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
#endif
