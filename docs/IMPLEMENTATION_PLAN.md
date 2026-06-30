# Step-by-Step Implementation Plan

This is the build order the codebase already follows, plus the roadmap for the
items intentionally left as future work. Each step is independently testable.

## Phase 0 — Foundations (done)
1. Swift Package with 7 library modules + app + per-module test targets,
   Swift 6 language mode (`Package.swift`).
2. `CoreModels`: entities, typed IDs, `SecretBytes`, `AppError`.

## Phase 1 — TOTP engine (done, fully tested)
3. `Base32` (RFC 4648), `OTPGenerator` (RFC 4226 HOTP + RFC 6238 TOTP over
   CryptoKit), `OTPAuthURI` parse/serialize.
4. Tests against all RFC 6238 Appendix B vectors + RFC 4226 HOTP vectors.

## Phase 2 — Storage (done, tested)
5. `SQLiteDatabase` wrapper + migrations; `SQLiteMetadataStore` actor.
6. `SecretStore` protocol; Keychain + in-memory implementations.
7. CRUD/round-trip tests.

## Phase 3 — Security services (done, tested)
8. `Authenticator` (LocalAuthentication) + `VaultService` gating.
9. `ClipboardManager` with auto-clear + secure mode.
10. `BackupKit`: PBKDF2 + AES-GCM envelope; round-trip/tamper/leak tests.

## Phase 4 — Domain orchestration (done, tested)
11. `Library` (observable cache + write-through), `SettingsStore`,
    `BackupCoordinator`, `FuzzyMatcher`, `AppEnvironment` DI root.
12. Vault-gating, fuzzy-ranking, and library tests.

## Phase 5 — SwiftUI app (done)
13. `AppModel` + `LockCoordinator` (sleep/screen-lock/inactivity/focus policies).
14. Lock screen, three-column main window, list/row, detail (code + QR + meta).
15. Add (QR/URI/manual) + edit flows, group editor.
16. Menu bar mode, Settings (general/security/backup/about), empty states.
17. `Info.plist`, entitlements, `build_app.sh` bundling + signing.

## Phase 6 — Roadmap (designed-for, not yet built)
18. **Secure Enclave master password:** generate a SE `SecKey` with a biometric
    ACL; derive/verify the master password against it. Hook into
    `UnlockMethod.masterPassword`. Touch points: `VaultKit`, `VaultService`,
    Security settings tab.
19. **Nested-group UI:** the schema already has `parent_id`; render an
    `OutlineGroup` tree in `SidebarView` and support drag-into-group.
20. **Spotlight (`CSSearchableItem`)** for entry *names only* (never secrets),
    **Quick Look** preview, and **App Shortcuts** (`AppIntents`) for "copy code
    for <issuer>" with biometric gating.
21. **Launch at login** via `SMAppService.mainApp` wired to the existing
    `AppSettings.launchAtLogin` toggle.
22. **Global hotkey** to summon the menu bar search.
23. **iCloud/CloudKit sync:** metadata via CloudKit; secrets via iCloud Keychain
    or an end-to-end-encrypted record. The ID-stable models and `BackupDocument`
    make this additive — no schema rewrite.
24. **Custom app icon** (`Resources/AppIcon.icns`) and onboarding walkthrough.

## How to extend safely

- New persisted field → add a migration string to `Schema.migrations` (never
  edit an applied one) and bump nothing else; `user_version` handles upgrades.
- New secret-touching feature → route it through `VaultService` so the lock gate
  and wiping are inherited; add a gating test.
- New module → keep the inward-only dependency rule and add a test target.
