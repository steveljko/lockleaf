# Architecture

## Goals

1. **Security first.** Secrets never touch SQLite, logs, or crash reports. They
   exist decrypted only for the microseconds needed to compute a code, in a
   buffer that is explicitly zeroed afterward.
2. **Native & fast.** SwiftUI + the Observation framework, a single shared clock
   for all countdowns, in-memory caches for instant list rendering.
3. **Testable & maintainable.** Clean layering, dependency injection, protocol
   seams, small files, no global mutable state, no singletons in the domain.

## Layered design (Clean Architecture)

```
┌─────────────────────────────────────────────────────────────┐
│ TwoFactorApp (SwiftUI)                                        │  Presentation
│   App/  DesignSystem/  Lock/  Main/  Detail/  Editor/         │
│   Settings/  MenuBar/  QR/  Onboarding/                       │
├─────────────────────────────────────────────────────────────┤
│ DomainServices                                                │  Use cases /
│   VaultService · Library · SettingsStore · BackupCoordinator  │  orchestration
│   AppEnvironment (composition root) · FuzzyMatcher · Clock    │
├───────────────┬───────────────┬───────────────┬──────────────┤
│ TOTPCore      │ KeychainStore │ Persistence   │ VaultKit      │  Services
│ RFC engine    │ SecretStore   │ MetadataStore │ Authenticator │  & adapters
│ otpauth       │ (Keychain)    │ (SQLite actor)│ Clipboard     │
├───────────────┴───────────────┴───────────────┴──────────────┤
│ BackupKit (PBKDF2 + AES-GCM envelope, BackupDocument DTO)     │
├─────────────────────────────────────────────────────────────┤
│ CoreModels (entities, value types, SecretBytes, AppError)    │  Domain core
└─────────────────────────────────────────────────────────────┘
```

Dependencies point **inward**. `CoreModels` depends on nothing. The UI depends
on the domain; the domain never imports SwiftUI/AppKit (except `VaultKit`'s
clipboard, which is an OS adapter by nature).

## Key components

### CoreModels
Pure value types: `Entry`, `Group`, `Tag`, `OTPParameters`, `Avatar`,
`AppSettings`, typed `Identifier<…>` IDs, `AppError`. Crucially, **`Entry` holds
a `SecretReference` (an opaque Keychain account token), never a secret.**
`SecretBytes` is a reference-type buffer that `memset_s`-wipes on `deinit`.

### TOTPCore
Stateless `OTPGenerator` implementing HOTP (RFC 4226) and TOTP (RFC 6238) over
CryptoKit HMAC (SHA1/256/512), `Base32` (RFC 4648), and `OTPAuthURI`
parse/serialize. No Keychain, no I/O — exhaustively unit-tested against the RFC
vectors.

### KeychainStore
`SecretStore` protocol with two implementations: `KeychainSecretStore`
(`kSecClassGenericPassword`, `…WhenUnlockedThisDeviceOnly`, optional
`.userPresence` access control) and `InMemorySecretStore` (tests/previews).

### Persistence
A small, audited `SQLiteDatabase` wrapper over the system `SQLite3` module with
prepared statements and transactions. `SQLiteMetadataStore` is an **actor** that
serializes all DB access and exposes an async `MetadataStore` protocol. Schema
is migrated forward via `PRAGMA user_version`. **No secret columns exist.**

### VaultKit
`Authenticator` protocol over `LAContext` (`LocalAuthenticator` creates a fresh
context per attempt so a prior success can't be replayed) and
`ClipboardManager` (auto-clear by `changeCount`, secure/concealed mode).

### BackupKit
`BackupDocument`/`BackupEntry` DTOs (these *do* carry secrets, hence only ever
encrypted on disk), PBKDF2-HMAC-SHA256 (600k iterations) → AES-256-GCM envelope.

### DomainServices
- **`VaultService`** (`@Observable`, `@MainActor`): the single gate for secret
  access. Locked ⇒ every secret op throws `AppError.vaultLocked`. Reads a secret,
  computes a code, wipes the buffer.
- **`Library`**: in-memory observable cache of groups/entries/tags; writes fan
  out to `MetadataStore` (metadata) and `VaultService` (secrets).
- **`SettingsStore`**, **`BackupCoordinator`**, **`FuzzyMatcher`**, **`Clock`**.
- **`AppEnvironment`**: the composition root; `.live()` vs `.preview()`.

### TwoFactorApp
SwiftUI scenes: main `WindowGroup` (three-column `NavigationSplitView`),
`Settings`, and a `MenuBarExtra`. `AppModel` holds selection/search/error state
and the `LockCoordinator` (system-event → lock policy). `CodeClock` is one shared
timer; `CodeDisplay` recomputes the secret only at period boundaries.

## Concurrency model

- UI state and services that the UI touches are `@MainActor`.
- SQLite is confined to an `actor`; its handle never races.
- `SecretBytes` is `@unchecked Sendable` with controlled access.
- Swift 6 language mode is enabled package-wide; the build is data-race-checked.

## Why these trade-offs

- **System SQLite over an ORM/GRDB:** fewer dependencies, fully auditable SQL,
  and we only need simple metadata queries.
- **Keychain over app-managed encryption:** the OS already provides
  hardware-backed, access-controlled secret storage; rolling our own would be a
  net security regression.
- **No network entitlement at all:** eliminates exfiltration and tracking by
  construction; "logo lookup" is therefore omitted rather than compromised.
