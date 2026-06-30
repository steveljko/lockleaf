import CoreModels
import DomainServices
import SwiftUI

/// The detail pane: large live code, countdown, QR preview, and metadata, with
/// edit controls.
struct EntryDetailView: View {
    let entry: Entry

    @Environment(AppModel.self) private var model
    @Environment(Library.self) private var library
    @Environment(VaultService.self) private var vault

    @State private var showingEdit = false
    @State private var showingQR = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                GroupBox {
                    VStack(spacing: 16) {
                        CodeDisplay(entry: entry, fontSize: 40, ringSize: 44)
                        Button {
                            model.copyCode(for: entry)
                        } label: {
                            Label("Copy Code", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(8)
                }

                metadata

                if showingQR {
                    qrSection
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(entry.issuer.isEmpty ? entry.name : entry.issuer)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { library.toggleFavorite(entry) } label: {
                    Image(systemName: entry.isFavorite ? "star.fill" : "star")
                }
                .help("Favorite")
                Button { withAnimation { showingQR.toggle() } } label: {
                    Image(systemName: "qrcode")
                }
                .help("Show QR code")
                Button { showingEdit = true } label: {
                    Image(systemName: "pencil")
                }
                .help("Edit")
            }
        }
        .sheet(isPresented: $showingEdit) {
            EntryEditorView(editing: entry)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editEntryRequested)) { _ in
            showingEdit = true
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            AvatarView(avatar: entry.avatar, color: entry.color, seed: entry.issuer.isEmpty ? entry.name : entry.issuer, size: Metrics.avatarLarge)
            VStack(spacing: 2) {
                Text(entry.issuer.isEmpty ? entry.name : entry.issuer).font(.title2.weight(.semibold))
                if !entry.name.isEmpty { Text(entry.name).foregroundStyle(.secondary) }
            }
        }
    }

    private var metadata: some View {
        GroupBox("Details") {
            VStack(alignment: .leading, spacing: 10) {
                detailRow("Algorithm", entry.parameters.algorithm.displayName)
                detailRow("Digits", "\(entry.parameters.digits)")
                if entry.parameters.kind == .totp {
                    detailRow("Period", "\(entry.parameters.period)s")
                }
                if let groupID = entry.groupID, let group = library.groups.first(where: { $0.id == groupID }) {
                    detailRow("Group", group.name)
                }
                if !entry.notes.isEmpty {
                    Divider()
                    Text(entry.notes).font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                detailRow("Added", entry.createdAt.formatted(date: .abbreviated, time: .omitted))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var qrSection: some View {
        GroupBox("QR Code") {
            VStack(spacing: 8) {
                if vault.isLocked {
                    Text("Unlock to reveal the QR code.").foregroundStyle(.secondary).padding()
                } else if let image = qrImage {
                    Image(nsImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 200, height: 200)
                        .draggable(image)
                    Text("Drag to export or scan with another device.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Could not render QR code.").foregroundStyle(.secondary).padding()
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
        }
    }

    private var qrImage: NSImage? {
        guard let secret = try? vault.exportableSecret(for: entry) else { return nil }
        let uri = OTPAuthURIBuilder.make(entry: entry, base32Secret: secret)
        return QRCode.image(from: uri)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.callout)
    }
}
