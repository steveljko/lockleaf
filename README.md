# Lockleaf — Secure TOTP for macOS

Lockleaf is a native, security-first macOS app for storing and generating TOTP
(2FA) codes.
Secrets live only in the **Apple Keychain**; SQLite holds non-secret metadata.
The vault unlocks with **Touch ID** (or Apple Watch / account password) via the
`LocalAuthentication` framework. No analytics, no telemetry, no network access.

> Built with Swift 6, SwiftUI, the Observation framework, CryptoKit, and the
> system SQLite3 — **zero third-party dependencies** (smaller attack surface,
> nothing to supply-chain-compromise).

---

## Requirements

- macOS 15 (Sequoia) or later
- Swift 6 toolchain / Xcode 16+

## Quick start

```bash
# Run the full test suite (TOTP vectors, crypto, persistence, vault gating)
swift test

# Build a runnable, ad-hoc-signed .app bundle (no Xcode project needed)
./Scripts/build_app.sh release
open ./build/Lockleaf.app

# Package the .app into a drag-to-Applications .dmg installer
./Scripts/make_dmg.sh            # → build/Lockleaf-<version>.dmg
```

The `build_app.sh` script compiles the SwiftPM executable, wraps it in a
`.app` bundle with `Info.plist`, applies the sandbox + biometric entitlements,
and ad-hoc code-signs it so Keychain and Touch ID work locally.

## Project layout

```
Package.swift               Swift Package: 7 library modules + 1 app + 5 test targets
Sources/
  CoreModels/               Domain entities & value types (no platform deps, no secrets)
  TOTPCore/                 RFC 6238/4226 engine, Base32, otpauth:// parsing
  KeychainStore/            SecretStore protocol + Keychain + in-memory impls
  Persistence/              SQLite wrapper, schema/migrations, MetadataStore actor
  VaultKit/                 LocalAuthentication authenticator, clipboard manager
  BackupKit/                Encrypted backup (PBKDF2 + AES-GCM) and plain JSON
  DomainServices/           Use cases: VaultService, Library, Settings, DI container
  LockleafApp/              SwiftUI application (App, DesignSystem, views, QR)
Tests/                      One test target per logic module
Resources/                  Info.plist, entitlements (icon optional)
Scripts/build_app.sh        Bundle + sign the .app
Scripts/make_dmg.sh         Package the .app into a .dmg installer
docs/                       Architecture, threat model, security review, plan
```

## Module dependency graph

```
CoreModels  ←  TOTPCore, KeychainStore, Persistence, VaultKit
CoreModels, TOTPCore  ←  BackupKit
(all of the above)    ←  DomainServices  ←  LockleafApp (SwiftUI)
```

Dependencies point inward only; the UI knows the domain, the domain never
imports SwiftUI. Each layer is unit-testable in isolation with in-memory doubles
(`InMemorySecretStore`, `SQLiteMetadataStore.inMemory()`, stub authenticators).

## Testing strategy

| Layer | What's verified |
|-------|-----------------|
| `TOTPCore` | All RFC 6238 Appendix B vectors (SHA1/256/512, 8 digits), RFC 4226 HOTP vectors, Base32 round-trips, otpauth parsing/serialization |
| `Persistence` | CRUD round-trips, tag joins, recents ordering, settings JSON |
| `BackupKit` | Encrypt→decrypt round-trip, wrong-password rejection, tamper (GCM tag) detection, no-plaintext-leak assertion |
| `KeychainStore` | Secret lifecycle on the in-memory double, `SecretBytes` wiping |
| `DomainServices` | Fuzzy ranking, **vault gating** (locked vault throws on code/secret access), Library add/search/delete + secret cleanup |

Run `swift test`. Keychain- and biometric-backed code paths are exercised
through protocols with deterministic doubles so the suite is hermetic; the real
`KeychainSecretStore` / `LocalAuthenticator` are integration-tested manually in
the running app (they require an entitled, signed bundle and a logged-in user).

## Building a notarizable app (Xcode path)

For App Store or Developer ID distribution:

1. Create a macOS App target in Xcode and add this package as a local dependency
   (or drag the `Sources/*` modules in as a workspace).
2. Set the target's Info.plist and entitlements to `Resources/Info.plist` and
   `Resources/Lockleaf.entitlements`.
3. Set your Team / Developer ID signing identity, enable Hardened Runtime.
4. Archive → notarize. The same `DomainServices` and library code is reused
   unchanged; only packaging differs.

## Continuous Integration & Releases

Two GitHub Actions workflows (in `.github/workflows/`):

- **`ci.yml`** — builds and runs the full test suite on every push to `main`
  and on pull requests (`macos-15`, latest stable Xcode).
- **`release.yml`** — on pushing a version tag, builds the signed `.app`, stamps
  it with the tag's version (`CFBundleShortVersionString`) and the run number
  (`CFBundleVersion`), builds a drag-to-Applications **`.dmg` installer**
  (`Scripts/make_dmg.sh`, native `hdiutil`), also zips the bare `.app`, and
  publishes a GitHub Release with both artifacts attached.

Cut a release:

```bash
git tag v1.0.0
git push origin v1.0.0        # → Actions builds & publishes the release
```

(Or run the **Release** workflow manually from the Actions tab and pass the
version.) First-time setup, if this isn't a git repo yet:

```bash
git init && git add . && git commit -m "Initial commit"
git branch -M main
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
```

The released `.app` is **ad-hoc signed, not notarized** (CI has no Developer ID
by default), so Gatekeeper will warn on first launch — the release notes tell
users to right-click → Open. To produce a notarized artifact in CI, add your
Developer ID certificate and an App Store Connect API key as repository secrets,
import the cert into a temporary keychain, sign with `--sign "Developer ID
Application: …"`, and run `xcrun notarytool submit … --wait` before zipping.

## What's implemented vs. designed-for

**Fully implemented & tested:** RFC 6238/4226 engine, otpauth parsing & QR
generation, Base32, Keychain secret store, SQLite metadata store with
migrations, encrypted/plain backups, vault lock/unlock gating, auto-lock on
sleep / screen-lock / inactivity / focus-loss, clipboard auto-clear + secure
mode, fuzzy search, groups/tags/favorites/pins/recents, three-column UI, lock
screen, add (QR/URI/manual)/edit flows, menu bar mode, settings, QR import via
image/drag/paste.

**Architecturally ready, intentionally minimal or deferred** (documented in
`docs/IMPLEMENTATION_PLAN.md`): Secure-Enclave-backed master-password unlock
(biometrics is the shipped default), nested-group UI (schema supports
`parent_id`), Spotlight/Quick Look/Shortcuts integration, and *network* logo
fetching (deliberately omitted — it would leak which services a user has;
instead an **offline brand-icon catalog** gives known issuers a recognizable
SF Symbol + color, and per-entry icons are user-pickable as auto/emoji/symbol/
image), iCloud/CloudKit sync (the `BackupDocument` DTO and ID-stable model are
designed to make this additive).

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md),
[`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md), and
[`docs/SECURITY.md`](docs/SECURITY.md).
