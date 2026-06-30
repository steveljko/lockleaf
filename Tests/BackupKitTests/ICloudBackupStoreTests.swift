import Testing
import Foundation
import CoreModels
@testable import BackupKit

@Suite("iCloud backup store")
struct ICloudBackupStoreTests {
    /// A fresh temp directory backing the store via its test seam.
    private func makeStore() -> (ICloudBackupStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lockleaf-icloud-test-\(UUID().uuidString)", isDirectory: true)
        return (ICloudBackupStore(directory: dir), dir)
    }

    @Test("Write then read round-trips the bytes")
    func roundTrip() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(store.isAvailable)
        #expect(try store.read() == nil)

        let payload = Data("encrypted-envelope".utf8)
        try store.write(payload)
        #expect(try store.read() == payload)
        #expect(store.lastModified() != nil)
    }

    @Test("Write replaces the previous backup in place")
    func overwrite() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try store.write(Data("first".utf8))
        try store.write(Data("second".utf8))
        #expect(try store.read() == Data("second".utf8))
    }

    @Test("Remove deletes the backup and is a no-op when absent")
    func remove() throws {
        let (store, dir) = makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        try store.remove() // nothing written yet
        try store.write(Data("x".utf8))
        try store.remove()
        #expect(try store.read() == nil)
        #expect(store.lastModified() == nil)
    }
}
