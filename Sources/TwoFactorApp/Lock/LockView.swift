import DomainServices
import SwiftUI
import VaultKit

/// Full-window lock screen. Triggers the native Touch ID dialog on appear and
/// offers a manual unlock button as a fallback.
struct LockView: View {
    @Environment(AppModel.self) private var model
    @Environment(VaultService.self) private var vault

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: vault.state == .unlocking ? "lock.open" : "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: vault.state)
                .contentTransition(.symbolEffect(.replace))

            VStack(spacing: 6) {
                Text("Vault Locked")
                    .font(.title2.weight(.semibold))
                Text(prompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button(action: unlock) {
                Label(buttonTitle, systemImage: buttonSymbol)
                    .frame(minWidth: 180)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(vault.state == .unlocking)

            Spacer()
            Text("Your codes and secrets are hidden until you unlock.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .task { await model.unlock() }   // present biometrics immediately
    }

    private func unlock() {
        Task { await model.unlock() }
    }

    private var prompt: String {
        switch vault.biometryKind {
        case .touchID: "Use Touch ID to unlock your 2FA vault."
        case .faceID: "Use Face ID to unlock your 2FA vault."
        case .opticID: "Use Optic ID to unlock your 2FA vault."
        case .none: "Authenticate to unlock your 2FA vault."
        }
    }

    private var buttonTitle: String {
        vault.state == .unlocking ? "Authenticating…" : "Unlock"
    }

    private var buttonSymbol: String {
        switch vault.biometryKind {
        case .touchID, .opticID: "touchid"
        case .faceID: "faceid"
        case .none: "key.fill"
        }
    }
}
