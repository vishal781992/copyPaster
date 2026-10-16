import SwiftUI

struct ClipboardTileView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onCopyPath: () -> Void
    let onRevealInFinder: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onOpenURL: (URL) -> Void
    let onOpenTerminal: (URL) -> Void

    @State private var isHovered = false

    private var tileColor: Color {
        switch item.contentType {
        case .text:     return .orange
        case .image:    return .yellow
        case .filePath: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Content preview
            Group {
                if item.contentType == .text {
                    Text(item.textContent ?? "")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if item.contentType == .filePath {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: (item.fileCount ?? 0) > 1 ? "doc.on.doc.fill" : "doc.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                        Text(item.textContent ?? "")
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if let nsImage = item.nsImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onDrag { imageDragProvider() }
                        .help("Drag into another app")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Metadata on the left, actions on the right — keeps short items compact
            HStack(spacing: 4) {
                switch item.contentType {
                case .text:
                    Text("\(item.characterCount) chars")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                case .image:
                    if let size = item.imageSizeDescription {
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let name = item.imageFileName {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Button(action: onRevealInFinder) {
                            Text(name)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder — \(item.imagePath ?? "")")
                    }
                case .filePath:
                    if let count = item.fileCount {
                        Text(count == 1 ? "1 file" : "\(count) files")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                actions
            }
        }
        .padding(12)
        .glassPanel(tint: tileColor,
                    tintOpacity: isHovered ? 0.20 : 0.10,
                    rim: item.isPinned ? Color.orange.opacity(0.7) : Color.white.opacity(isHovered ? 0.30 : 0.18))
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.spring(duration: 0.25), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var actions: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc.fill")
                        .glassIcon(.blue)
                }
                .buttonStyle(.plain)
                .help(item.contentType == .image ? "Copy image" : "Copy to clipboard")

                let urls = item.webURLs
                if urls.count == 1, let url = urls.first {
                    Button { onOpenURL(url) } label: {
                        Image(systemName: "safari")
                            .glassIcon(.teal)
                    }
                    .buttonStyle(.plain)
                    .help("Open \(url.absoluteString)")
                } else if urls.count > 1 {
                    Menu {
                        ForEach(urls, id: \.self) { url in
                            Button(url.absoluteString) { onOpenURL(url) }
                        }
                    } label: {
                        Image(systemName: "safari")
                            .glassIcon(.teal)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Open a link (\(urls.count) found)")
                }

                let dirs = item.terminalDirectories
                if dirs.count == 1, let dir = dirs.first {
                    Button { onOpenTerminal(dir) } label: {
                        Image(systemName: "terminal")
                            .glassIcon(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Open Terminal in \(dir.path)")
                } else if dirs.count > 1 {
                    Menu {
                        ForEach(dirs, id: \.self) { dir in
                            Button(dir.path) { onOpenTerminal(dir) }
                        }
                    } label: {
                        Image(systemName: "terminal")
                            .glassIcon(.gray)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Open Terminal in a folder (\(dirs.count) found)")
                }

                if item.contentType == .image {
                    Button(action: onCopyPath) {
                        Image(systemName: "link")
                            .glassIcon(.purple)
                    }
                    .buttonStyle(.plain)
                    .help("Copy image file path")
                }

                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .glassIcon(.orange, filled: item.isPinned)
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Unpin" : "Pin")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .glassIcon(.red)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
    }

    /// Prefers the on-disk file so targets like Finder and Mail receive a real file with its name;
    /// falls back to the in-memory image when the file has been moved or deleted.
    private func imageDragProvider() -> NSItemProvider {
        if item.imageFileExists, let path = item.imagePath,
           let provider = NSItemProvider(contentsOf: URL(fileURLWithPath: path)) {
            return provider
        }
        if let image = item.nsImage {
            return NSItemProvider(object: image)
        }
        return NSItemProvider()
    }
}
