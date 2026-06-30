import AppKit
import CoreModels
import DomainServices
import SwiftUI
import UniformTypeIdentifiers

/// Backup export/import. Encrypted export is the default and recommended path;
/// plain JSON requires an explicit confirmation because it contains secrets.
struct BackupSettingsTab: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(VaultService.self) private var vault
    @Environment(SettingsStore.self) private var settings
    @Environment(BackupManager.self) private var backupManager

    @State private var passwordSheet: PasswordSheet?
    @State private var message: String?
    @State private var confirmPlainExport = false
    @State private var confirmDisableICloud = false

    private enum PasswordSheet: Identifiable {
        case export, importFile(Data), enableICloud, restoreICloud
        var id: String {
            switch self {
            case .export: "export"
            case .importFile: "import"
            case .enableICloud: "enableICloud"
            case .restoreICloud: "restoreICloud"
            }
        }
    }

    private var backups: BackupCoordinator { environment.backups }

    var body: some View {
        Form {
            iCloudSection
            Section("Export") {
                Button {
                    passwordSheet = .export
                } label: { Label("Export Encrypted Backup…", systemImage: "lock.doc") }
                    .disabled(vault.isLocked)
                Button(role: .destructive) {
                    confirmPlainExport = true
                } label: { Label("Export Unencrypted JSON…", systemImage: "doc.plaintext") }
                    .disabled(vault.isLocked)
                Text("Encrypted backups are protected by a password using AES-256-GCM. Keep your password safe — it cannot be recovered.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Import") {
                Button {
                    importBackup()
                } label: { Label("Import Backup…", systemImage: "square.and.arrow.down") }
                    .disabled(vault.isLocked)
            }
            if vault.isLocked {
                Label("Unlock the vault to back up.", systemImage: "lock")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(item: $passwordSheet) { sheet in
            switch sheet {
            case .export:
                PasswordPrompt(title: "Encrypt Backup", confirm: true) { password in
                    runExportEncrypted(password: password)
                }
            case .importFile(let data):
                PasswordPrompt(title: "Backup Password", confirm: false) { password in
                    runImport(data: data, password: password)
                }
            case .enableICloud:
                PasswordPrompt(title: "Set Backup Password", confirm: true) { password in
                    enableICloud(password: password)
                }
            case .restoreICloud:
                PasswordPrompt(title: "Backup Password", confirm: false) { password in
                    runICloudRestore(password: password)
                }
            }
        }
        .confirmationDialog("Export unencrypted backup?", isPresented: $confirmPlainExport) {
            Button("Export Unencrypted", role: .destructive) { runExportPlain() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This file will contain your secrets in plain text. Anyone who reads it can generate your codes.")
        }
        .confirmationDialog("Turn off iCloud backup?", isPresented: $confirmDisableICloud) {
            Button("Turn Off & Delete", role: .destructive) { disableICloud() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The encrypted backup will be removed from iCloud and the backup password forgotten. Your codes on this Mac are not affected.")
        }
        .alert("Backup", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    // MARK: - iCloud

    @ViewBuilder
    private var iCloudSection: some View {
        Section("iCloud") {
            Toggle("Back up to iCloud", isOn: iCloudToggle)
                .disabled(vault.isLocked || !backups.isICloudAvailable)

            if settings.settings.iCloudBackupEnabled {
                Button {
                    Task { await backupManager.backUpNow() }
                } label: { Label("Back Up Now", systemImage: "arrow.clockwise.icloud") }
                    .disabled(vault.isLocked || backupManager.status == .backingUp)
                Button {
                    passwordSheet = .enableICloud
                } label: { Label("Change Backup Password…", systemImage: "key") }
                    .disabled(vault.isLocked)
            }

            Button {
                passwordSheet = .restoreICloud
            } label: { Label("Restore from iCloud…", systemImage: "icloud.and.arrow.down") }
                .disabled(vault.isLocked || !backups.isICloudAvailable)

            iCloudStatus
        }
    }

    @ViewBuilder
    private var iCloudStatus: some View {
        if !backups.isICloudAvailable {
            Label("Sign in to iCloud and enable iCloud Drive to use this.", systemImage: "icloud.slash")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            switch backupManager.status {
            case .backingUp:
                Label("Backing up…", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption).foregroundStyle(.secondary)
            case .failed(let reason):
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            case .succeeded, .idle:
                if let date = backups.iCloudBackupDate {
                    Text("Last backed up \(date.formatted(.relative(presentation: .named))).")
                        .font(.caption).foregroundStyle(.secondary)
                } else if settings.settings.iCloudBackupEnabled {
                    Text("Encrypted backups sync automatically after changes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Intercepts the toggle so enabling can collect a password first and
    /// disabling can confirm before deleting the cloud copy.
    private var iCloudToggle: Binding<Bool> {
        Binding(
            get: { settings.settings.iCloudBackupEnabled },
            set: { wantsOn in
                if wantsOn {
                    if backups.hasBackupPassword {
                        settings.update { $0.iCloudBackupEnabled = true }
                        Task { await backupManager.backUpNow() }
                    } else {
                        passwordSheet = .enableICloud
                    }
                } else {
                    confirmDisableICloud = true
                }
            }
        )
    }

    private func enableICloud(password: String) {
        do {
            try backups.setBackupPassword(password)
            settings.update { $0.iCloudBackupEnabled = true }
            Task { await backupManager.backUpNow() }
        } catch { message = (error as? AppError)?.userMessage ?? error.localizedDescription }
    }

    private func disableICloud() {
        settings.update { $0.iCloudBackupEnabled = false }
        do {
            try backups.removeICloudBackup()
            try backups.clearBackupPassword()
        } catch { message = (error as? AppError)?.userMessage ?? error.localizedDescription }
    }

    private func runICloudRestore(password: String) {
        do {
            try backups.restoreFromICloud(password: password)
            message = "Backup restored from iCloud."
        } catch { message = (error as? AppError)?.userMessage ?? error.localizedDescription }
    }

    // MARK: - Actions

    private func runExportEncrypted(password: String) {
        do {
            let data = try environment.backups.exportEncrypted(password: password)
            try save(data, suggestedName: "Lockleaf-Backup.lockleafbackup")
            message = "Encrypted backup saved."
        } catch { message = (error as? AppError)?.userMessage ?? error.localizedDescription }
    }

    private func runExportPlain() {
        do {
            let data = try environment.backups.exportPlain()
            try save(data, suggestedName: "Lockleaf-Backup.json")
            message = "Unencrypted backup saved."
        } catch { message = (error as? AppError)?.userMessage ?? error.localizedDescription }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json, UTType(filenameExtension: "lockleafbackup") ?? .data, .data]
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        if environment.backups.isEncrypted(data) {
            passwordSheet = .importFile(data)
        } else {
            runImport(data: data, password: nil)
        }
    }

    private func runImport(data: Data, password: String?) {
        do {
            try environment.backups.restore(data, password: password)
            message = "Backup imported."
        } catch { message = (error as? AppError)?.userMessage ?? error.localizedDescription }
    }

    private func save(_ data: Data, suggestedName: String) throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try data.write(to: url, options: [.atomic])
        }
    }
}

/// Reusable password prompt with optional confirmation field.
struct PasswordPrompt: View {
    let title: String
    let confirm: Bool
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""

    private var isValid: Bool {
        !password.isEmpty && (!confirm || password == confirmation)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            SecureField("Password", text: $password)
            if confirm {
                SecureField("Confirm password", text: $confirmation)
                if !confirmation.isEmpty && confirmation != password {
                    Text("Passwords don't match").font(.caption).foregroundStyle(.red)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Continue") { onSubmit(password); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
