import CoreModels
import DomainServices
import SwiftUI

/// Preferences window with native tabs.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            SecuritySettingsTab()
                .tabItem { Label("Security", systemImage: "lock.shield") }
            BackupSettingsTab()
                .tabItem { Label("Backup", systemImage: "externaldrive") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 420)
    }
}

private struct GeneralSettingsTab: View {
    @Environment(SettingsStore.self) private var store
    @Environment(Library.self) private var library

    var body: some View {
        Form {
            Picker("Appearance", selection: binding(\.theme)) {
                Text("System").tag(AppTheme.system)
                Text("Light").tag(AppTheme.light)
                Text("Dark").tag(AppTheme.dark)
            }
            Toggle("Launch at login", isOn: binding(\.launchAtLogin))
            Toggle("Show menu bar item", isOn: binding(\.menuBarMode))
            Toggle("Show in Dock", isOn: binding(\.showInDock))
            Picker("Default group for new codes", selection: binding(\.defaultGroupID)) {
                Text("None").tag(GroupID?.none)
                ForEach(library.groups) { Text($0.name).tag(GroupID?.some($0.id)) }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: keyPath] },
                set: { v in store.update { $0[keyPath: keyPath] = v } })
    }
}

private struct SecuritySettingsTab: View {
    @Environment(SettingsStore.self) private var store

    private let lockOptions: [(String, Int)] = [
        ("30 seconds", 30), ("1 minute", 60), ("5 minutes", 300),
        ("15 minutes", 900), ("1 hour", 3600), ("Never", 0),
    ]
    private let clipboardOptions: [(String, Int)] = [
        ("10 seconds", 10), ("20 seconds", 20), ("30 seconds", 30), ("1 minute", 60), ("Never", 0),
    ]

    var body: some View {
        Form {
            Section("Auto-Lock") {
                Picker("Lock after inactivity", selection: binding(\.autoLockSeconds)) {
                    ForEach(lockOptions, id: \.1) { Text($0.0).tag($0.1) }
                }
                Toggle("Lock when Mac sleeps", isOn: binding(\.lockOnSleep))
                Toggle("Lock when screen locks", isOn: binding(\.lockOnScreenLock))
                Toggle("Lock when app loses focus", isOn: binding(\.lockWhenAppLosesFocus))
            }
            Section("Clipboard") {
                Picker("Clear copied code after", selection: binding(\.clipboardClearSeconds)) {
                    ForEach(clipboardOptions, id: \.1) { Text($0.0).tag($0.1) }
                }
                Toggle("Secure clipboard (exclude from history & Handoff)", isOn: binding(\.secureClipboard))
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: keyPath] },
                set: { v in store.update { $0[keyPath: keyPath] = v } })
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill").font(.system(size: 56)).foregroundStyle(.tint)
            Text("Lockleaf").font(.title.bold())
            Text("Secure TOTP for macOS").foregroundStyle(.secondary)
            Text("Secrets are stored in the Apple Keychain and never leave your Mac. No analytics, no telemetry, no tracking.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
