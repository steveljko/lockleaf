import DomainServices
import SwiftUI

/// Shows the lock screen until the vault is unlocked, then the main window. The
/// transition is a quick crossfade so unlocking feels instant.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(VaultService.self) private var vault

    var body: some View {
        Group {
            if vault.isLocked {
                LockView()
            } else {
                MainWindowView()
            }
        }
        .animation(.smooth(duration: 0.25), value: vault.isLocked)
        .frame(minWidth: 720, idealWidth: 1000, minHeight: 460, idealHeight: 640)
    }
}
