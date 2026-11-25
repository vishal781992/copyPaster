import SwiftUI
import ImageIO

struct ClipboardTileView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onCopyPath: () -> Void
    let onRevealInFinder: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onOpenURL: (URL) -> Void
    let onOpenTerminal: (URL) -> Void
    let onSetPassword: (Bool) -> Void
    var isRewriting: Bool = false
    var onRewrite: ((RewriteStyle) -> Void)? = nil

    @State private var isHovered = false
    @State private var justCopied = false
    @State private var copyToken = 0
    /// True only while the eye button is held down.
    @State private var isRevealing = false
    @State private var thumbnail: NSImage?
    @AppStorage(ClipboardManager.passwordLifetimeKey)
    private var passwordLifetimeHours = ClipboardManager.defaultPasswordLifetimeHours

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Content preview
            Group {
                if item.isMasked {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(isRevealing ? item.previewText : item.maskedPreview)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(isRevealing ? .primary : .secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        passwordBadge
                    }
                } else if item.contentType == .text {
                    Text(item.previewText)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if item.contentType == .filePath {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: (item.fileCount ?? 0) > 1 ? "doc.on.doc.fill" : "doc.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        Text(item.previewText)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if item.contentType == .image {
                    Group {
                        if let image = thumbnail ?? ThumbnailCache.cached(item.id) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .onDrag { imageDragProvider() }
                                .help("Drag into another app")
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.quaternary)
                                .frame(width: 128, height: 80)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .task(id: item.id) { thumbnail = await ThumbnailCache.load(item) }
                }
            }

            // Metadata on the left, actions on the right — keeps short items compact
            HStack(spacing: 4) {
                switch item.contentType {
                case .text where item.isMasked:
                    // No character count: it would give away the length
                    EmptyView()
                case .text:
                    Text("\(TileDetails.of(item).characterCount) chars")
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
                        .buttonStyle(.pressable)
                        .help("Reveal in Finder — \(item.imagePath ?? "")")
                    }
                case .filePath:
                    if let count = item.fileCount {
                        Text(count == 1 ? "1 file" : "\(count) files")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !item.isMasked {
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(item.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .help(imageExpiryHelp)
                Spacer(minLength: 8)
                actions
            }
        }
        .padding(12)
        .glassPanel(tint: .primary,
                    tintOpacity: isHovered ? 0.05 : 0,
                    rim: item.isPinned ? Color.accentColor.opacity(0.6) : Color(nsColor: .separatorColor))
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.spring(duration: 0.25), value: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu {
            if item.contentType == .text {
                if item.isMasked {
                    Button("Not a Password") { onSetPassword(false) }
                } else {
                    Button("Mark as Password") { onSetPassword(true) }
                }
            }
        }
    }

    /// Compact lock capsule in the tile's top-right corner; the tooltip spells it out.
    private var passwordBadge: some View {
        Label(item.passwordLabel, systemImage: "lock.fill")
            .labelStyle(.titleAndIcon)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.orange)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.orange.opacity(0.15)))
            .help(badgeHelp)
    }

    private var imageExpiryHelp: String {
        guard item.contentType == .image, let expiry = item.expiry(lifetimeHours: passwordLifetimeHours) else { return "" }
        return "Removed from history \(expiry.formatted(.relative(presentation: .named)))"
    }

    private var badgeHelp: String {
        guard let expiry = item.expiry(lifetimeHours: passwordLifetimeHours) else { return item.passwordHelp }
        return "\(item.passwordHelp)\nDeleted automatically \(expiry.formatted(.relative(presentation: .named)))"
    }

    private var actions: some View {
        AdaptiveGlassContainer(spacing: 6) {
            HStack(spacing: 6) {
                Button(action: copyWithFeedback) {
                    HStack(spacing: 4) {
                        Image(systemName: justCopied ? "checkmark" : "doc.on.doc.fill")
                            .contentTransition(.symbolEffect(.replace))
                        Text(justCopied ? "Copied" : "Copy")
                    }
                    .glassPill()
                }
                .buttonStyle(.pressable)
                .help(item.contentType == .image ? "Copy image" : "Copy to clipboard")

                if item.isMasked {
                    // Hold to reveal: the text hides again as soon as the mouse is released
                    Image(systemName: isRevealing ? "eye.fill" : "eye")
                        .glassIcon(isRevealing ? .orange : nil)
                        .onLongPressGesture(minimumDuration: .infinity, perform: {}) { pressing in
                            isRevealing = pressing
                        }
                        .help("Hold to reveal")
                }

                let urls = item.isMasked ? [] : TileDetails.of(item).webURLs
                if urls.count == 1, let url = urls.first {
                    Button { onOpenURL(url) } label: {
                        Image(systemName: "safari")
                            .glassIcon()
                    }
                    .buttonStyle(.pressable)
                    .help("Open \(url.absoluteString)")
                } else if urls.count > 1 {
                    Menu {
                        ForEach(urls, id: \.self) { url in
                            Button(url.absoluteString) { onOpenURL(url) }
                        }
                    } label: {
                        Image(systemName: "safari")
                            .glassIcon()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Open a link (\(urls.count) found)")
                }

                let dirs = item.isMasked ? [] : TileDetails.of(item).terminalDirectories
                if dirs.count == 1, let dir = dirs.first {
                    Button { onOpenTerminal(dir) } label: {
                        Image(systemName: "terminal")
                            .glassIcon()
                    }
                    .buttonStyle(.pressable)
                    .help("Open Terminal in \(dir.path)")
                } else if dirs.count > 1 {
                    Menu {
                        ForEach(dirs, id: \.self) { dir in
                            Button(dir.path) { onOpenTerminal(dir) }
                        }
                    } label: {
                        Image(systemName: "terminal")
                            .glassIcon()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Open Terminal in a folder (\(dirs.count) found)")
                }

                if item.contentType == .image {
                    Button(action: onCopyPath) {
                        Image(systemName: "link")
                            .glassIcon()
                    }
                    .buttonStyle(.pressable)
                    .help("Copy image file path")
                }

                if let onRewrite, TileDetails.of(item).isRewritable {
                    if isRewriting {
                        ProgressView()
                            .controlSize(.small)
                            .glassIcon()
                            .help("Rewriting with Claude…")
                    } else {
                        Menu {
                            ForEach(RewriteStyle.allCases) { style in
                                Button { onRewrite(style) } label: {
                                    Label(style.label, systemImage: style.symbol)
                                }
                            }
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .glassIcon()
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("Rewrite professionally with Claude")
                    }
                }

                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .glassIcon(item.isPinned ? .accentColor : nil)
                }
                .buttonStyle(.pressable)
                .help(item.isPinned ? "Unpin" : "Pin")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .glassIcon()
                }
                .buttonStyle(.pressable)
                .help("Delete")
            }
        }
    }

    /// Copies, then flips the button to "Copied" for a moment. The token keeps a quick
    /// second click from being cut short by the first click's reset.
    private func copyWithFeedback() {
        onCopy()
        copyToken += 1
        let token = copyToken
        withAnimation(.spring(duration: 0.3)) { justCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard token == copyToken else { return }
            withAnimation(.spring(duration: 0.3)) { justCopied = false }
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

/// Link detection, folder checks and counting characters are too slow to repeat on every render
/// while scrolling, so each item's results are worked out once. Text items don't change after capture.
private struct TileDetails {
    let characterCount: Int
    let webURLs: [URL]
    let terminalDirectories: [URL]
    let isRewritable: Bool

    @MainActor private static var cache: [UUID: TileDetails] = [:]

    @MainActor static func of(_ item: ClipboardItem) -> TileDetails {
        if let hit = cache[item.id] { return hit }
        let details = TileDetails(characterCount: item.characterCount,
                                  webURLs: item.webURLs,
                                  terminalDirectories: item.terminalDirectories,
                                  isRewritable: AIRewriter.isRewritable(item))
        cache[item.id] = details
        return details
    }
}

/// Small previews of image items. Decoding a full-size screenshot on the main thread for every
/// render made scrolling stutter; these are downsampled once, off the main thread, and kept.
enum ThumbnailCache {
    private static let cache = NSCache<NSUUID, NSImage>()
    /// Longest side in pixels — enough for the 80pt-tall preview on a Retina display.
    private static let maxPixelSize = 720

    static func cached(_ id: UUID) -> NSImage? {
        cache.object(forKey: id as NSUUID)
    }

    static func load(_ item: ClipboardItem) async -> NSImage? {
        if let hit = cached(item.id) { return hit }
        guard let data = item.imageData else { return nil }
        let size = maxPixelSize
        let cgImage = await Task.detached(priority: .userInitiated) { downsample(data, maxPixelSize: size) }.value
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: item.id as NSUUID)
        return image
    }

    private nonisolated static func downsample(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
