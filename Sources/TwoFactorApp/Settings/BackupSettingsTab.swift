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

    @State private var passwordSheet: PasswordSheet?
    @State private var message: String?
    @State private var confirmPlainExport = false

    private enum PasswordSheet: Identifiable {
        case export, importFile(Data)
        var id: String { switch self { case .export: "export"; case .importFile: "import" } }
    }

    var body: some View {
        Form {
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
            }
        }
        .confirmationDialog("Export unencrypted backup?", isPresented: $confirmPlainExport) {
            Button("Export Unencrypted", role: .destructive) { runExportPlain() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This file will contain your secrets in plain text. Anyone who reads it can generate your codes.")
        }
        .alert("Backup", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    // MARK: - Actions

    private func runExportEncrypted(password: String) {
        do {
            let data = try environment.backups.exportEncrypted(password: password)
            try save(data, suggestedName: "TwoFactor-Backup.2fabackup")
            message = "Encrypted backup saved."
        } catch { message = (error as? AppError)?.userMessage ?? error.localizedDescription }
    }

    private func runExportPlain() {
        do {
            let data = try environment.backups.exportPlain()
            try save(data, suggestedName: "TwoFactor-Backup.json")
            message = "Unencrypted backup saved."
        } catch { message = (error as? AppError)?.userMessage ?? error.localizedDescription }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json, UTType(filenameExtension: "2fabackup") ?? .data, .data]
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
