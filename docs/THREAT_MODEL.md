# Threat Model

## Assets

| Asset | Sensitivity |
|-------|-------------|
| TOTP shared secrets | **Critical** — disclosure permanently compromises the 2FA factor |
| Generated codes | High (short-lived) |
| Metadata (issuer, account, notes, groups) | Moderate — privacy |
| Backup files | Critical if unencrypted; protected if encrypted |

## Trust boundaries

- **Apple Keychain / Secure Enclave** — trusted. Hardware-backed, OS-mediated.
- **App process memory** — semi-trusted; minimized exposure and wiped.
- **SQLite file & app container** — trusted for metadata only; assumed readable
  by a sufficiently privileged local attacker, so it holds **no secrets**.
- **Pasteboard** — untrusted shared surface; treated as hostile (auto-clear,
  concealed type).
- **Network** — out of scope: the app has **no network entitlement**.

## Adversaries & mitigations

### A1 — Thief with the unlocked-but-unattended Mac
- Auto-lock on inactivity, on sleep, on screen lock, on fast-user-switch, and
  optionally on focus loss (`LockCoordinator`).
- Locking clears the clipboard and drops all decrypted state.
- **Residual risk:** within the inactivity window the vault may be open. Mitigate
  with a short auto-lock and "lock on focus loss".

### A2 — Local malware / another app reading the vault
- Secrets are in the Keychain (`…ThisDeviceOnly`), not in the SQLite file.
- Optional `.userPresence` ACL forces Touch ID on *every* secret read, so even
  code running as the user can't silently extract secrets.
- App Sandbox confines file access; no network egress is possible.
- **Residual risk:** code injected into *this* process while unlocked. Hardened
  Runtime + signature + not loading plugins reduce this.

### A3 — Disk / Time Machine / iCloud backup theft
- Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: excluded
  from iCloud Keychain and not restorable to another device.
- SQLite contains no secrets, so a stolen DB yields only metadata.

### A4 — Stolen exported backup file
- Encrypted backups: AES-256-GCM with a PBKDF2-HMAC-SHA256 key (600k iterations,
  random 16-byte salt). Offline guessing is throttled by the KDF; GCM detects
  tampering. Tests assert the secret never appears in the ciphertext file.
- Unencrypted JSON export requires an explicit, separate confirmation dialog and
  is clearly labeled as containing secrets in plaintext.

### A5 — Shoulder-surfing / clipboard sniffers / clipboard managers
- Codes are concealed when locked.
- Copy uses the `org.nspasteboard.ConcealedType`/`TransientType` conventions so
  clipboard managers and Universal Clipboard skip the value (secure mode).
- Clipboard auto-clears after a configurable timeout, only if unchanged since.

### A6 — Secrets leaking via logs / crash reports
- Secrets are never passed to `print`/`os_log`; `AppError` messages never embed
  secret material.
- `SecretBytes` keeps secrets out of `Data`'s reusable allocations and zeroes on
  release, shrinking the window a crash dump could capture them.

### A7 — Malicious otpauth URI / QR (parser abuse)
- Parsing is total and defensive: unknown schemes/types, missing/invalid Base32
  secrets, and malformed labels are rejected with typed errors. No code path
  executes data from a URI.

## Explicit non-goals

- Defending against a **compromised OS / kernel** or hardware implants.
- Protecting against an attacker who already has the user's biometrics/password.
- Network-based sync security (no sync ships yet; CloudKit would add its own
  model).
