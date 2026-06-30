# Security Review

A checklist-style review of the requirements against the implementation, with
file references for auditing.

## Secret handling

| Requirement | Status | Where |
|-------------|--------|-------|
| Secrets only in Keychain | ✅ | `KeychainStore/KeychainSecretStore.swift` |
| SQLite stores only metadata | ✅ | `Persistence/Schema.swift` (no secret column); `CoreModels/Entry.swift` holds `SecretReference` only |
| Never write decrypted secrets to disk | ✅ | Secrets flow Keychain → `SecretBytes` → HMAC; backups are encrypted unless the user explicitly opts into plain JSON |
| Never log secrets | ✅ | No logging of secret values anywhere; `AppError` messages are secret-free |
| Not in crash reports | ✅ (best-effort) | `SecretBytes.wipe()` via `memset_s` in `deinit`; secrets not stored on long-lived objects |
| Decrypted only while needed | ✅ | `VaultService.generateCode` loads, computes, `defer { secret.wipe() }` |
| Secure memory wipe | ✅ | `CoreModels/SecretBytes.swift` |
| Clipboard auto-clear | ✅ | `VaultKit/ClipboardManager.swift` |
| Secure clipboard mode | ✅ | Concealed/transient pasteboard types |
| No analytics / telemetry / tracking | ✅ | No network entitlement (`Resources/TwoFactor.entitlements`); no analytics SDKs |

## Keychain configuration

- Class: `kSecClassGenericPassword`, fixed service `app.twofactor.secrets`.
- Accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  → not in iCloud Keychain, not restorable to another device, readable only
  while the Mac is unlocked.
- Optional `SecAccessControlCreateWithFlags(..., .userPresence)` to require Touch
  ID/password on every individual secret read (`requireUserPresence: true`).
- Duplicate-safe writes (delete-then-add); typed error mapping via
  `SecCopyErrorMessageString`.

## Authentication

- `LocalAuthentication` with `.deviceOwnerAuthentication` (biometrics incl.
  Apple Watch, falling back to the macOS account password).
- A **fresh `LAContext` per unlock** so a cached evaluation can't bypass re-lock
  (`VaultKit/Authenticator.swift`).
- The vault is the only secret gate: `VaultService` throws `AppError.vaultLocked`
  for code generation, secret export, and storage while locked — unit-tested in
  `DomainServicesTests` ("Vault gating").

## Backup cryptography

- KDF: PBKDF2-HMAC-SHA256, 600,000 iterations (CommonCrypto), 16-byte random
  salt per backup.
- Cipher: AES-256-GCM (CryptoKit) with a random nonce; the GCM tag authenticates
  the ciphertext (tamper detection tested).
- The envelope stores only non-secret KDF params + nonce + ciphertext. Tests
  assert the plaintext secret/issuer are absent from the encrypted bytes.

## Sandboxing & distribution

- App Sandbox enabled; only `files.user-selected.read-write` for backup panels.
- **No** `com.apple.security.network.*` entitlement — exfiltration is impossible
  by capability.
- `build_app.sh` signs with Hardened Runtime options; production builds should be
  Developer ID-signed and notarized.

## Known limitations / follow-ups

- The shipped unlock is biometrics/device-password. A **separate master password
  bound to a Secure Enclave key** (`UnlockMethod.masterPassword`) is modeled in
  settings but not yet wired to a SE `SecKey`; see the implementation plan.
- `SecretBytes` reduces but cannot fully eliminate secret residue (Swift may copy
  bytes through `Data` at the CryptoKit boundary); acceptable given the Keychain
  is the system of record.
- Memory protection assumes a non-compromised OS (see threat model non-goals).
