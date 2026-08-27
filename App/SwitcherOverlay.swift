// Window switcher (hyper+space): a Spotlight-style panel — type to filter
// tracked windows, see which workspace each lives on, Enter focuses it.
// Doubles as a command palette: ">" prefixes commands (layout, pause,
// preset...), an all-digit query jumps to that workspace.
// Main-thread only. The panel is non-activating so it takes keyboard input
// without dragging our accessory app into the foreground.

import AppKit
import Bar
import SwiftUI

struct SwitcherEntry: Identifiable, Equatable {
    let id: UInt32
    let pid: pid_t
    let appName: String
    let title: String
    /// "2 🌐 web" — number + icon + custom label.
    let workspaceTitle: String
    let isFocused: Bool
}

/// A palette action. `command` is a raw command-grammar string, dispatched
/// through `Command.parse` — the same single path as keybindings.
struct PaletteEntry: Identifiable, Equatable {
    var id: String { command }
    let command: String
    let title: String
}

/// Borderless windows refuse key status by default — the whole point of the
/// switcher is typing into it.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class SwitcherOverlay {
    private var panel: NSPanel?
    private var resignObserver: NSObjectProtocol?
    private let onChoose: (UInt32) -> Void
    private let onCommand: (String) -> Void

    init(onChoose: @escaping (UInt32) -> Void, onCommand: @escaping (String) -> Void) {
        self.onChoose = onChoose
        self.onCommand = onCommand
    }

    var isVisible: Bool { panel != nil }

    func show(entries: [SwitcherEntry], palette: [PaletteEntry], initialQuery: String = "") {
        hide()
        let panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.becomesKeyOnlyIfNeeded = false
        panel.contentView = NSHostingView(
            rootView: SwitcherView(
                entries: entries,
                palette: palette,
                initialQuery: initialQuery,
                onChoose: { [weak self] id in
                    self?.hide()
                    self?.onChoose(id)
                },
                onCommand: { [weak self] command in
                    self?.hide()
                    self?.onCommand(command)
                },
                onCancel: { [weak self] in self?.hide() }
            )
        )

        let size = NSSize(width: 560, height: 380)
        let screen = NSScreen.main ?? NSScreen.screens[0]
        panel.setFrame(
            NSRect(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2 + 80,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        // Clicking anywhere else dismisses the switcher, like Spotlight.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.hide() }
    }

    func hide() {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }
}

private enum SwitcherRowItem: Identifiable, Equatable {
    case window(SwitcherEntry)
    case command(PaletteEntry)

    var id: String {
        switch self {
        case .window(let entry): return "w\(entry.id)"
        case .command(let entry): return "c\(entry.id)"
        }
    }
}

private struct SwitcherView: View {
    let entries: [SwitcherEntry]
    let palette: [PaletteEntry]
    let onChoose: (UInt32) -> Void
    let onCommand: (String) -> Void
    let onCancel: () -> Void

    @State private var query: String
    @State private var selection = 0
    @FocusState private var searchFocused: Bool

    init(
        entries: [SwitcherEntry],
        palette: [PaletteEntry],
        initialQuery: String,
        onChoose: @escaping (UInt32) -> Void,
        onCommand: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.entries = entries
        self.palette = palette
        self.onChoose = onChoose
        self.onCommand = onCommand
        self.onCancel = onCancel
        _query = State(initialValue: initialQuery)
    }

    private var rows: [SwitcherRowItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.hasPrefix(">") {
            let needle = q.dropFirst().trimmingCharacters(in: .whitespaces).lowercased()
            let hits = needle.isEmpty ? palette : palette.filter {
                $0.title.lowercased().contains(needle) || $0.command.lowercased().contains(needle)
            }
            return hits.map(SwitcherRowItem.command)
        }
        if !q.isEmpty, q.allSatisfy(\.isNumber) {
            return [.command(PaletteEntry(command: "workspace \(q)", title: L10n.switchToWorkspace(q)))]
        }
        return filteredWindows(q).map(SwitcherRowItem.window)
    }

    private func filteredWindows(_ query: String) -> [SwitcherEntry] {
        guard !query.isEmpty else { return entries }
        let needle = query.lowercased()
        let matches = entries.filter {
            $0.appName.lowercased().contains(needle) || $0.title.lowercased().contains(needle)
        }
        // Prefix matches on the app name first — "sa" should rank Safari
        // above an app whose window title merely contains "sa".
        return matches.sorted { a, b in
            let ap = a.appName.lowercased().hasPrefix(needle)
            let bp = b.appName.lowercased().hasPrefix(needle)
            if ap != bp { return ap }
            return a.appName < b.appName
        }
    }

    private func choose(_ row: SwitcherRowItem) {
        switch row {
        case .window(let entry): onChoose(entry.id)
        case .command(let entry): onCommand(entry.command)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField(L10n.switcherPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .light))
                .padding(14)
                .focused($searchFocused)
                .onChange(of: query) { _, _ in selection = 0 }
                .onSubmit {
                    if rows.indices.contains(selection) { choose(rows[selection]) }
                }
                .onKeyPress(.downArrow) {
                    selection = min(selection + 1, max(0, rows.count - 1))
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    selection = max(selection - 1, 0)
                    return .handled
                }
                .onKeyPress(.escape) {
                    onCancel()
                    return .handled
                }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            Group {
                                switch row {
                                case .window(let entry):
                                    SwitcherRow(entry: entry, isSelected: index == selection)
                                case .command(let entry):
                                    PaletteRow(entry: entry, isSelected: index == selection)
                                }
                            }
                            .id(row.id)
                            .onTapGesture { choose(row) }
                        }
                    }
                    .padding(6)
                }
                .onChange(of: selection) { _, new in
                    if rows.indices.contains(new) {
                        proxy.scrollTo(rows[new].id)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
        .onAppear { searchFocused = true }
    }
}

private struct PaletteRow: View {
    let entry: PaletteEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white.opacity(0.8) : .secondary)
                .frame(width: 26)
            Text(entry.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : .primary)
            Spacer(minLength: 12)
            Text(entry.command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white.opacity(0.7) : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor : Color.clear))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SwitcherRow: View {
    let entry: SwitcherEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if let icon = NSRunningApplication(processIdentifier: entry.pid)?.icon {
                Image(nsImage: icon).resizable().frame(width: 26, height: 26)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.appName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : .primary)
                if !entry.title.isEmpty, entry.title != entry.appName {
                    Text(entry.title)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            if entry.isFocused {
                Circle().fill(isSelected ? Color.white : Color.accentColor).frame(width: 6, height: 6)
            }
            Text(entry.workspaceTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? Color.white.opacity(0.9) : .secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.08)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor : Color.clear))
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
