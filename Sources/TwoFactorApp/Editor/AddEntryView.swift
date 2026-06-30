import AppKit
import CoreModels
import DomainServices
import SwiftUI
import TOTPCore
import UniformTypeIdentifiers

/// Add-account sheet with three import paths: QR image, otpauth URI, and manual
/// entry. All paths converge on `Library.addEntry`.
struct AddEntryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case qr = "Scan QR", uri = "Paste Link", manual = "Manual"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @Environment(Library.self) private var library

    @State private var mode: Mode = .qr
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                Group {
                    switch mode {
                    case .qr: QRImportPane(onParsed: add, onError: show)
                    case .uri: URIImportPane(onParsed: add, onError: show)
                    case .manual: ManualEntryPane(onSave: addManual, onError: show)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 520)
        .alert("Couldn't add entry", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Add Account").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(20)
    }

    private func add(_ uri: OTPAuthURI) {
        do {
            let entry = try library.addEntry(from: uri, groupID: model.settings.settings.defaultGroupID)
            model.selectedEntryID = entry.id
            dismiss()
        } catch { show((error as? AppError)?.userMessage ?? error.localizedDescription) }
    }

    private func addManual(_ draft: ManualDraft) {
        do {
            let entry = try library.addEntry(
                name: draft.name, issuer: draft.issuer, base32Secret: draft.secret,
                parameters: draft.parameters, groupID: draft.groupID,
                avatar: draft.avatar, color: draft.color, notes: draft.notes
            )
            model.selectedEntryID = entry.id
            dismiss()
        } catch { show((error as? AppError)?.userMessage ?? error.localizedDescription) }
    }

    private func show(_ message: String) { errorMessage = message }
}

// MARK: - QR pane

private struct QRImportPane: View {
    let onParsed: (OTPAuthURI) -> Void
    let onError: (String) -> Void
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.5))
                .frame(height: 220)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 44)).foregroundStyle(.secondary)
                        Text("Drag a QR image or screenshot here").foregroundStyle(.secondary)
                    }
                }
                .background(isTargeted ? Color.accentColor.opacity(0.06) : .clear)
                .dropDestination(for: URL.self) { urls, _ in handleURLs(urls) } isTargeted: { isTargeted = $0 }

            HStack {
                Button { chooseFile() } label: { Label("Choose Image…", systemImage: "photo") }
                Button { pasteFromClipboard() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
            }
            Text("We scan locally on your Mac — nothing is uploaded.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func handleURLs(_ urls: [URL]) -> Bool {
        guard let url = urls.first, let image = NSImage(contentsOf: url) else { return false }
        return scan(image)
    }

    @discardableResult
    private func scan(_ image: NSImage) -> Bool {
        let payloads = QRCode.decode(image)
        for payload in payloads {
            if let uri = try? OTPAuthURI(string: payload) {
                onParsed(uri); return true
            }
        }
        onError("No 2FA QR code was found in that image.")
        return false
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            scan(image)
        }
    }

    private func pasteFromClipboard() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            onError("There's no image on the clipboard."); return
        }
        scan(image)
    }
}

// MARK: - URI pane

private struct URIImportPane: View {
    let onParsed: (OTPAuthURI) -> Void
    let onError: (String) -> Void
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste an otpauth:// link").font(.headline)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            Button("Add") {
                do { onParsed(try OTPAuthURI(string: text)) }
                catch { onError((error as? AppError)?.userMessage ?? "Invalid link") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
