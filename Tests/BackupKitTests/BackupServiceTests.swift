import Testing
import Foundation
import CoreModels
@testable import BackupKit

@Suite("Backup service")
struct BackupServiceTests {
    let service = BackupService()

    private func sampleDocument() -> BackupDocument {
        let id = EntryID()
        let entry = BackupEntry(
            id: id, name: "alice", issuer: "GitHub",
            base32Secret: "JBSWY3DPEHPK3PXP",
            parameters: OTPParameters(algorithm: .sha256, digits: 8, period: 60),
            notes: "n", groupID: nil, tagIDs: [], isFavorite: true, isPinned: false
        )
        return BackupDocument(groups: [Group(name: "Work")], tags: [], entries: [entry])
    }

    @Test("Encrypted backup round-trips with the right password")
    func encryptedRoundTrip() throws {
        let doc = sampleDocument()
        // Use fewer iterations to keep the test fast; still exercises the path.
        let data = try service.exportEncrypted(doc, password: "correct horse", iterations: 10_000)
        #expect(service.isEncrypted(data))
        let restored = try service.importEncrypted(data, password: "correct horse")
        #expect(restored == doc)
    }

    @Test("Wrong password fails authentication")
    func wrongPassword() throws {
        let data = try service.exportEncrypted(sampleDocument(), password: "right", iterations: 10_000)
        #expect(throws: AppError.self) {
            try service.importEncrypted(data, password: "wrong")
        }
    }

    @Test("Tampered ciphertext is rejected")
    func tamperDetection() throws {
        var data = try service.exportEncrypted(sampleDocument(), password: "pw", iterations: 10_000)
        // Flip a byte in the middle of the file.
        let index = data.count / 2
        data[index] ^= 0xFF
        #expect(throws: AppError.self) {
            try service.importEncrypted(data, password: "pw")
        }
    }

    @Test("Plain backup round-trips and is detected as unencrypted")
    func plainRoundTrip() throws {
        let doc = sampleDocument()
        let data = try service.exportPlain(doc)
        #expect(!service.isEncrypted(data))
        #expect(try service.importPlain(data) == doc)
    }

    @Test("Encrypted file does not leak the secret in plaintext")
    func noPlaintextLeak() throws {
        let data = try service.exportEncrypted(sampleDocument(), password: "pw", iterations: 10_000)
        let asString = String(decoding: data, as: UTF8.self)
        #expect(!asString.contains("JBSWY3DPEHPK3PXP"))
        #expect(!asString.contains("GitHub"))
    }
}
