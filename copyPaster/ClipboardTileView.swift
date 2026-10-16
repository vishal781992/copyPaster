import SwiftUI

struct ClipboardTileView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onCopyPath: () -> Void
    let onRevealInFinder: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onOpenURL: (URL) -> Void

    @State private var isHovered = false

    private var tileColor: Color {
        switch item.contentType {
        case .text:     return .orange
        case .image:    return .yellow
        case .filePath: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Actions
                VStack(spacing: 8) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help(item.contentType == .image ? "Copy image" : "Copy to clipboard")

                    let urls = item.webURLs
                    if urls.count == 1, let url = urls.first {
                        Button { onOpenURL(url) } label: {
                            Image(systemName: "safari")
                                .font(.system(size: 14))
                                .foregroundStyle(.teal)
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
                                .font(.system(size: 14))
                                .foregroundStyle(.teal)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("Open a link (\(urls.count) found)")
                    }

                    if item.contentType == .image {
                        Button(action: onCopyPath) {
                            Image(systemName: "link")
                                .font(.system(size: 13))
                                .foregroundStyle(.purple)
                        }
                        .buttonStyle(.plain)
                        .help("Copy image file path")
                    }

                    Button(action: onTogglePin) {
                        Image(systemName: item.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 11))
                            .foregroundStyle(item.isPinned ? .white : .secondary)
                            .frame(width: 22, height: 22)
                            .background(item.isPinned ? Color.orange : Color.clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(item.isPinned ? "Unpin" : "Pin")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }

            // Metadata row — below content, never overlaps actions
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
                Spacer()
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? tileColor.opacity(0.13) : tileColor.opacity(0.06))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.isPinned ? Color.orange.opacity(0.5) : tileColor.opacity(0.15), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

}
