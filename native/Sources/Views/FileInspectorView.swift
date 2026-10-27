import SwiftUI

public struct FileInspectorView: View {
    @ObservedObject var store: DataStore
    @State private var selectedQDFIndex: Int = 0

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quicken Data Format Inspector")
                        .font(.system(.title, design: .serif, weight: .bold))
                    Text("Decompiled File Structures & Binary Specifications of the 1999–2000 Era")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Current Loaded Path
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Data Directory:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(store.loadedDirectoryPath)
                            .font(.system(.caption, design: .monospaced, weight: .medium))
                    }
                    Spacer()
                    Button(action: promptDirectoryOpen) {
                        Label("Choose Folder...", systemImage: "folder")
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // QDF Files Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quicken Database Files (.QDF)")
                        .font(.headline)

                    if store.qdfFiles.isEmpty {
                        Text("No .QDF files detected in active directory.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(store.qdfFiles.enumerated()), id: \.offset) { idx, qdf in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "internaldrive.fill")
                                        .foregroundColor(.purple)
                                    Text(URL(fileURLWithPath: qdf.filePath).lastPathComponent)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text("\(qdf.fileSize / 1024) KB • \(qdf.pageCount) Pages")
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 16) {
                                    Text(String(format: "Magic: 0x%08X (AC 9E BD 8F)", qdf.magic))
                                    Text(String(format: "Version: 0x%08X", qdf.version))
                                    Text("Page Size: 4,088 bytes (0xFF8)")
                                    Text("Cipher: RC5-32 + MD5")
                                }
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)

                                // First 6 pages breakdown preview
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Page Table Preview:")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                    ForEach(Array(qdf.pages.prefix(6))) { page in
                                        HStack {
                                            Text(String(format: "Page %2d [Offset 0x%06X]:", page.pageIndex, page.offset))
                                                .frame(width: 170, alignment: .leading)
                                            Text(page.isEncrypted ? "RC5 Encrypted" : "Clear Header + Catalog")
                                                .frame(width: 170, alignment: .leading)
                                                .foregroundColor(page.isEncrypted ? .secondary : .green)
                                            Text("MD5: \(page.md5Digest.prefix(16))...")
                                                .foregroundColor(.secondary)
                                        }
                                        .font(.system(size: 10, design: .monospaced))
                                    }
                                }
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                                .cornerRadius(6)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }

                // QSD Files Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Structured String Tables (.QSD)")
                        .font(.headline)

                    if store.qsdFiles.isEmpty {
                        Text("No .QSD files detected.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(store.qsdFiles.enumerated()), id: \.offset) { idx, qsd in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "text.alignleft")
                                        .foregroundColor(.blue)
                                    Text(URL(fileURLWithPath: qsd.filePath).lastPathComponent)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(qsd.versionString)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }

                                if !qsd.recognizedAccounts.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Recognized Account Entities:")
                                            .font(.caption2.bold())
                                            .foregroundColor(.secondary)
                                        Text(qsd.recognizedAccounts.joined(separator: " • "))
                                            .font(.caption2)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Extracted String Tokens:")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                    Text(qsd.extractedStrings.prefix(30).joined(separator: ", "))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func promptDirectoryOpen() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Quicken Data Directory"
        if panel.runModal() == .OK, let url = panel.url {
            store.loadDirectory(path: url.path)
        }
    }
}
