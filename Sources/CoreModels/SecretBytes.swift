import Foundation

/// A heap buffer for secret material that is **explicitly zeroed when it is no
/// longer referenced**. Use this instead of `Data`/`[UInt8]` for raw OTP secrets
/// so that decrypted bytes do not linger in reusable allocator memory.
///
/// `SecretBytes` is a `final class` (reference type) precisely so that wiping
/// happens deterministically in `deinit`, and so copies share one buffer rather
/// than silently spraying secret bytes across many value copies.
public final class SecretBytes: @unchecked Sendable {
    private var storage: UnsafeMutableRawBufferPointer

    public var count: Int { storage.count }

    public init(_ bytes: [UInt8]) {
        storage = UnsafeMutableRawBufferPointer.allocate(
            byteCount: bytes.count,
            alignment: MemoryLayout<UInt8>.alignment
        )
        bytes.withUnsafeBytes { storage.copyMemory(from: $0) }
    }

    public convenience init(_ data: Data) {
        self.init([UInt8](data))
    }

    /// Run `body` with temporary access to the raw bytes. Prefer this over
    /// exposing a `Data` copy so the secret stays in one controlled buffer.
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(storage))
    }

    /// Escape hatch for APIs (HMAC) that require `Data`. The returned copy is the
    /// caller's responsibility; keep its lifetime as short as possible.
    public func unsafeData() -> Data {
        Data(bytes: storage.baseAddress!, count: storage.count)
    }

    /// Overwrite the buffer with zeroes immediately. Idempotent.
    public func wipe() {
        if storage.count > 0, let base = storage.baseAddress {
            memset_s(base, storage.count, 0, storage.count)
        }
    }

    deinit {
        wipe()
        storage.deallocate()
    }
}
