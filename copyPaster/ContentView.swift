import SwiftUI

enum ClipboardFilter: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case images = "Images"
    case filePaths = "pwd"
}

struct ContentView: View {
    @Environment(ClipboardManager.self) private var manager
    @State private var searchText = ""
    @State private var selectedFilter: ClipboardFilter = .all
    @State private var showClearConfirmation = false
    @State private var showAddText = false

    private var filteredItems: [ClipboardItem] {
        var result = manager.items

        switch selectedFilter {
        case .all: break
        case .text:      result = result.filter { $0.contentType == .text }
        case .images:    result = result.filter { $0.contentType == .image }
        case .filePaths: result = result.filter { $0.contentType == .filePath }
        }

        if !searchText.isEmpty {
            result = result.filter {
                ($0.textContent?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.imagePath?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("CopyPaster")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(AppVersion.display)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                        .help("Build \(AppVersion.build)")
                    if manager.isPaused {
                        Text("Paused")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                    }
                    Spacer()
                    Button(action: { manager.openWeblinksFile() }) {
                        Image(systemName: "link.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open saved Weblinks file")

                    // Pause / Resume
                    Button(action: { manager.togglePause() }) {
                        Image(systemName: manager.isPaused ? "play.circle.fill" : "pause.circle")
                            .font(.title3)
                            .foregroundStyle(manager.isPaused ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(manager.isPaused ? "Resume monitoring" : "Pause monitoring")
                    .animation(.easeInOut(duration: 0.2), value: manager.isPaused)

                    Button(action: { showClearConfirmation = true }) {
                        Text("Clear All")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all history")
                    .alert("Clear All History?", isPresented: $showClearConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear All", role: .destructive) { manager.clearAll() }
                    } message: {
                        Text("This will delete all clipboard items. Pinned items will also be removed.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search clipboard...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.body)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)

                // Category tabs
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(ClipboardFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Item count
                HStack {
                    Text("\(filteredItems.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

                // Tiles list with FAB overlay
                ZStack(alignment: .bottomTrailing) {
                    if filteredItems.isEmpty {
                        VStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "clipboard")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.quaternary)
                                Text("No items yet")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Text("Copy something and it'll appear here")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredItems) { item in
                                    ClipboardTileView(
                                        item: item,
                                        onCopy: { manager.copyToClipboard(item) },
                                        onCopyPath: { manager.copyImagePath(item) },
                                        onRevealInFinder: { manager.revealImageInFinder(item) },
                                        onDelete: { withAnimation(.easeOut(duration: 0.2)) { manager.deleteItem(item) } },
                                        onTogglePin: { withAnimation(.easeInOut(duration: 0.2)) { manager.togglePin(item) } },
                                        onOpenURL: { manager.openURL($0) }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, showAddText ? 12 : 64)
                        }
                    }

                    // FAB
                    Button {
                        withAnimation(.spring(duration: 0.3)) { showAddText.toggle() }
                    } label: {
                        Image(systemName: showAddText ? "xmark" : "square.and.pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(showAddText ? Color(nsColor: .tertiaryLabelColor) : Color.accentColor, in: Circle())
                            .shadow(color: showAddText ? .clear : Color.accentColor.opacity(0.4), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                    .animation(.spring(duration: 0.25), value: showAddText)
                }

                // Compose panel
                if showAddText {
                    AddTextView(isShowing: $showAddText)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Toast overlay
            if manager.showToast {
                ToastView(message: manager.toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 4)
                    .animation(.easeInOut(duration: 0.3), value: manager.showToast)
            }
        }
        .frame(minWidth: 360, minHeight: 480)
    }
}

#Preview {
    ContentView()
        .environment(ClipboardManager.shared)
}
