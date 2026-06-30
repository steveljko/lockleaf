import Testing
import Foundation
import CoreModels
@testable import KeychainStore

@Suite("In-memory secret store")
struct InMemorySecretStoreTests {
    @Test("Saves, loads, and deletes secrets")
    func lifecycle() throws {
        let store = InMemorySecretStore()
        let ref = SecretReference(account: "test")
        #expect(!store.exists(ref))

        try store.save(SecretBytes([1, 2, 3, 4]), for: ref)
        #expect(store.exists(ref))

        let loaded = try #require(try store.load(ref))
        #expect(loaded.withUnsafeBytes { Array($0) } == [1, 2, 3, 4])

        try store.delete(ref)
        #expect(!store.exists(ref))
        #expect(try store.load(ref) == nil)
    }

    @Test("Saving twice replaces the value")
    func replace() throws {
        let store = InMemorySecretStore()
        let ref = SecretReference(account: "x")
        try store.save(SecretBytes([1]), for: ref)
        try store.save(SecretBytes([9, 9]), for: ref)
        let loaded = try #require(try store.load(ref))
        #expect(loaded.withUnsafeBytes { Array($0) } == [9, 9])
    }
}

@Suite("SecretBytes")
struct SecretBytesTests {
    @Test("Wipe zeroes the buffer")
    func wipe() {
        let secret = SecretBytes([0xAA, 0xBB, 0xCC])
        secret.wipe()
        #expect(secret.withUnsafeBytes { Array($0) } == [0, 0, 0])
    }
}
