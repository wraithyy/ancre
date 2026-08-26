// First-run onboarding: shows which permissions ancre still needs
// (Accessibility, Input Monitoring), deep-links to System Settings, and only
// starts the window manager once everything is granted and the user hits
// Start. Shown only when something is missing.

import AppKit
import Bar
import IOKit.hid
import SwiftUI

final class PermissionsModel: ObservableObject {
    @Published var accessibility = false
    @Published var inputMonitoring = false
    private var timer: Timer?

    var allGranted: Bool { accessibility && inputMonitoring }

    static func check() -> (accessibility: Bool, input: Bool) {
        (
            AXIsProcessTrusted(),
            IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        )
    }

    func startPolling() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let status = Self.check()
        if status.accessibility != accessibility { accessibility = status.accessibility }
        if status.input != inputMonitoring { inputMonitoring = status.input }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        open(pane: "Privacy_Accessibility")
    }

    func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        open(pane: "Privacy_ListenEvent")
    }

    private func open(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}

final class OnboardingWindow {
    private var window: NSWindow?
    private let model = PermissionsModel()

    /// Shows the onboarding and calls `onStart` when the user hits Start
    /// (enabled once every permission is granted).
    func show(onStart: @escaping () -> Void) {
        model.startPolling()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ancre"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: OnboardingView(model: model) { [weak self] in
                self?.close()
                onStart()
            }
        )
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func close() {
        model.stopPolling()
        window?.orderOut(nil)
        window = nil
    }
}

private struct OnboardingView: View {
    @ObservedObject var model: PermissionsModel
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ancre")
                    .font(.system(size: 28, weight: .bold))
                Text(L10n.onboardingSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                PermissionRow(
                    granted: model.accessibility,
                    title: "Accessibility",
                    detail: L10n.onboardingAccessibility,
                    action: model.requestAccessibility
                )
                PermissionRow(
                    granted: model.inputMonitoring,
                    title: "Input Monitoring",
                    detail: L10n.onboardingInputMonitoring,
                    action: model.requestInputMonitoring
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.onboardingHowTo)
                    .font(.system(size: 12, weight: .semibold))
                ForEach(Array(L10n.onboardingTips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(tip.0)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .frame(width: 150, alignment: .trailing)
                            .foregroundStyle(Color.accentColor)
                        Text(tip.1)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

            Label(L10n.onboardingAI, systemImage: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Label(L10n.onboardingRemapWarning, systemImage: "keyboard")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Spacer()
                Button(action: onStart) {
                    Text(L10n.onboardingStart)
                        .frame(minWidth: 120)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .disabled(!model.allGranted)
            }
        }
        .padding(24)
        .frame(width: 480, height: 560)
    }
}

private struct PermissionRow: View {
    let granted: Bool
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(granted ? Color.green : Color.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button(L10n.onboardingGrant, action: action)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}
