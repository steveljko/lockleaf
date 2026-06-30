import SwiftUI

/// Friendly empty states for the list column.
struct EmptyStateView: View {
    let isSearching: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isSearching ? "magnifyingglass" : "key.horizontal")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text(isSearching ? "No matching codes" : "No codes yet")
                .font(.title3.weight(.semibold))
            Text(isSearching
                 ? "Try a different search term."
                 : "Add your first account to start generating codes.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !isSearching {
                Button {
                    NotificationCenter.default.post(name: .newEntryRequested, object: nil)
                } label: {
                    Label("Add Entry", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder shown in the detail pane when nothing is selected.
struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("Select a code")
                .font(.title3.weight(.semibold))
            Text("Choose an account to see its code, QR, and details.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
