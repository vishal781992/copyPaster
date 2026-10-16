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

    @Namespace private var filterGlass

    private func count(for filter: ClipboardFilter) -> Int {
        switch filter {
        case .all:       return manager.items.count
        case .text:      return manager.items.filter { $0.contentType == .text }.count
        case .images:    return manager.items.filter { $0.contentType == .image }.count
        case .filePaths: return manager.items.filter { $0.contentType == .filePath }.count
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Soft color wash behind everything so the glass has something to refract.
            LinearGradient(
                colors: [Color.indigo.opacity(0.16), Color.teal.opacity(0.08), Color.orange.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                header
                searchField
                filterBar

                // Tiles list with FAB overlay
                ZStack(alignment: .bottomTrailing) {
                    if filteredItems.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredItems) { item in
                                    ClipboardTileView(
                                        item: item,
                                        onCopy: { manager.copyToClipboard(item) },
                                        onCopyPath: { manager.copyImagePath(item) },
                                        onRevealInFinder: { manager.revealImageInFinder(item) },
                                        onDelete: { withAnimation(.easeOut(duration: 0.2)) { manager.deleteItem(item) } },
                                        onTogglePin: { withAnimation(.easeInOut(duration: 0.2)) { manager.togglePin(item) } },
                                        onOpenURL: { manager.openURL($0) },
                                        onOpenTerminal: { manager.openTerminal(at: $0) }
                                    )
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 2)
                            .padding(.bottom, showAddText ? 12 : 68)
                        }
                        .scrollIndicators(.never)
                    }

                    // FAB
                    if !showAddText {
                        Button {
                            withAnimation(.spring(duration: 0.3)) { showAddText = true }
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .glassIcon(.accentColor, size: 44, iconSize: 15)
                        }
                        .buttonStyle(.plain)
                        .help("New snippet")
                        .padding(16)
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                // Compose panel
                if showAddText {
                    AddTextView(isShowing: $showAddText)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Toast overlay
            if manager.showToast {
                ToastView(message: manager.toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 6)
                    .animation(.easeInOut(duration: 0.3), value: manager.showToast)
            }
        }
        .frame(minWidth: 360, minHeight: 480)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("CopyPaster")
                .font(.title2)
                .fontWeight(.bold)
            Text(AppVersion.display)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .glassEffect(.regular, in: Capsule())
                .help("Build \(AppVersion.build)")
            if manager.isPaused {
                Text("Paused")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .glassEffect(.regular.tint(.orange.opacity(0.7)), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer()

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: { manager.openWeblinksFile() }) {
                        Image(systemName: "link")
                            .glassIcon(.indigo, size: 28, iconSize: 12)
                    }
                    .buttonStyle(.plain)
                    .help("Open saved Weblinks file")

                    // Pause / Resume
                    Button(action: { withAnimation(.spring(duration: 0.3)) { manager.togglePause() } }) {
                        Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                            .glassIcon(manager.isPaused ? .orange : .mint, size: 28, iconSize: 12)
                    }
                    .buttonStyle(.plain)
                    .help(manager.isPaused ? "Resume monitoring" : "Pause monitoring")

                    Button(action: { showClearConfirmation = true }) {
                        Image(systemName: "trash")
                            .glassIcon(.red, size: 28, iconSize: 12)
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
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    /// Glass segmented control: the selected pill is one glass shape that morphs between tabs.
    private var filterBar: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(ClipboardFilter.allCases, id: \.self) { filter in
                    let selected = filter == selectedFilter
                    Button {
                        withAnimation(.spring(duration: 0.35, bounce: 0.2)) { selectedFilter = filter }
                    } label: {
                        HStack(spacing: 4) {
                            Text(filter.rawValue)
                            Text("\(count(for: filter))")
                                .monospacedDigit()
                                .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary)
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(selected ? .regular.tint(Color.accentColor.opacity(0.7)).interactive() : .identity,
                                 in: Capsule())
                    .glassEffectID(selected ? "selection" : filter.rawValue, in: filterGlass)
                }
            }
            .padding(3)
            .glassEffect(.regular, in: Capsule())
        }
        .padding(.horizontal, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 72, height: 72)
                .glassEffect(.regular, in: Circle())
            Text("No items yet")
                .font(.headline)
            Text("Copy something and it'll appear here")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environment(ClipboardManager.shared)
}
