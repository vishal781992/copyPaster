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
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .auto
    @AppStorage("keepOnTop") private var keepOnTop = false
    @State private var hostWindow: NSWindow?
    @State private var defaultWindowLevel: NSWindow.Level?

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
                        .buttonStyle(.pressable)
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
        .onChange(of: appearance) { _, new in new.apply() }
        .background(WindowReader(window: $hostWindow))
        .onChange(of: hostWindow) { applyKeepOnTop() }
        .onChange(of: keepOnTop) { applyKeepOnTop() }
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
                .adaptiveGlass(in: Capsule())
                .help("Build \(AppVersion.build)")
            if manager.isPaused {
                Label("Paused", systemImage: "pause.fill")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .adaptiveGlass(in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            Spacer()

            AdaptiveGlassContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: { manager.openWeblinksFile() }) {
                        Image(systemName: "link")
                            .glassIcon(size: 28, iconSize: 12)
                    }
                    .buttonStyle(.pressable)
                    .help("Open saved Weblinks file")

                    // Pause / Resume
                    Button(action: { withAnimation(.spring(duration: 0.3)) { manager.togglePause() } }) {
                        Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                            .glassIcon(size: 28, iconSize: 12)
                    }
                    .buttonStyle(.pressable)
                    .help(manager.isPaused ? "Resume monitoring" : "Pause monitoring")

                    Button(action: { showClearConfirmation = true }) {
                        Image(systemName: "trash")
                            .glassIcon(size: 28, iconSize: 12)
                    }
                    .buttonStyle(.pressable)
                    .help("Clear all history")
                    .alert("Clear All History?", isPresented: $showClearConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear All", role: .destructive) { manager.clearAll() }
                    } message: {
                        Text("This will delete all clipboard items. Pinned items will also be removed.")
                    }

                    Button(action: { keepOnTop.toggle() }) {
                        Image(systemName: keepOnTop ? "pin.fill" : "pin")
                            .contentTransition(.symbolEffect(.replace))
                            .glassIcon(keepOnTop ? .accentColor : nil, size: 28, iconSize: 12)
                    }
                    .buttonStyle(.pressable)
                    .help(keepOnTop ? "Stop keeping on top" : "Keep on top")

                    // Appearance: cycles Auto → Light → Dark
                    Button(action: { appearance = appearance.next }) {
                        Image(systemName: appearance.symbol)
                            .contentTransition(.symbolEffect(.replace))
                            .glassIcon(size: 28, iconSize: 12)
                    }
                    .buttonStyle(.pressable)
                    .help("Appearance: \(appearance.label) — click for \(appearance.next.label)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    /// Floats the hosting window above other apps and stops the popover closing on outside clicks.
    private func applyKeepOnTop() {
        AppDelegate.shared?.setKeepOnTop(keepOnTop)
        guard let window = hostWindow else { return }
        if defaultWindowLevel == nil { defaultWindowLevel = window.level }
        window.level = keepOnTop ? .floating : (defaultWindowLevel ?? .normal)
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
                .buttonStyle(.pressable)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .adaptiveGlass(in: Capsule())
        .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    /// Glass segmented control: the selected pill is one glass shape that morphs between tabs.
    private var filterBar: some View {
        AdaptiveGlassContainer(spacing: 4) {
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
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.pressable)
                    .adaptiveGlassSelection(selected, id: filter.rawValue, in: filterGlass)
                }
            }
            .padding(3)
            .adaptiveGlass(in: Capsule())
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
                .adaptiveGlass(in: Circle())
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
