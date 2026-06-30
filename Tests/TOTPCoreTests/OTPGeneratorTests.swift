import Testing
import Foundation
@testable import TOTPCore
import CoreModels

/// RFC 6238 Appendix B reference vectors. The seeds are ASCII strings repeated
/// to the block size of each hash.
private let sha1Seed = Data("12345678901234567890".utf8)
private let sha256Seed = Data("12345678901234567890123456789012".utf8)
private let sha512Seed = Data("1234567890123456789012345678901234567890123456789012345678901234".utf8)

@Suite("RFC 6238 TOTP vectors")
struct OTPGeneratorTests {

    struct Vector {
        let time: TimeInterval
        let sha1: String
        let sha256: String
        let sha512: String
    }

    let vectors: [Vector] = [
        .init(time: 59,          sha1: "94287082", sha256: "46119246", sha512: "90693936"),
        .init(time: 1111111109,  sha1: "07081804", sha256: "68084774", sha512: "25091201"),
        .init(time: 1111111111,  sha1: "14050471", sha256: "67062674", sha512: "99943326"),
        .init(time: 1234567890,  sha1: "89005924", sha256: "91819424", sha512: "93441116"),
        .init(time: 2000000000,  sha1: "69279037", sha256: "90698825", sha512: "38618901"),
        .init(time: 20000000000, sha1: "65353130", sha256: "77737706", sha512: "47863826"),
    ]

    @Test("All Appendix B vectors match for SHA1/256/512")
    func referenceVectors() {
        for v in vectors {
            let date = Date(timeIntervalSince1970: v.time)
            #expect(OTPGenerator.generate(secret: sha1Seed, at: date, algorithm: .sha1, digits: 8, period: 30) == v.sha1)
            #expect(OTPGenerator.generate(secret: sha256Seed, at: date, algorithm: .sha256, digits: 8, period: 30) == v.sha256)
            #expect(OTPGenerator.generate(secret: sha512Seed, at: date, algorithm: .sha512, digits: 8, period: 30) == v.sha512)
        }
    }

    @Test("Six-digit codes are zero-padded")
    func sixDigits() {
        // Truncated form of the 8-digit "94287082" vector.
        let code = OTPGenerator.generate(secret: sha1Seed, at: Date(timeIntervalSince1970: 59), algorithm: .sha1, digits: 6, period: 30)
        #expect(code == "287082")
        #expect(code.count == 6)
    }

    @Test("HOTP RFC 4226 vectors")
    func hotpVectors() {
        // RFC 4226 Appendix D, secret "12345678901234567890".
        let expected = ["755224", "287082", "359152", "969429", "338314"]
        for (counter, code) in expected.enumerated() {
            let result = OTPGenerator.generate(secret: sha1Seed, counter: UInt64(counter), algorithm: .sha1, digits: 6)
            #expect(result == code)
        }
    }

    @Test("Live code reports a sane countdown")
    func liveCountdown() {
        let date = Date(timeIntervalSince1970: 1111111100) // 20s into a 30s window
        let live = OTPGenerator.liveCode(secret: sha1Seed, parameters: .init(algorithm: .sha1, digits: 8, period: 30), at: date)
        #expect(live.secondsRemaining == 10)
        #expect(live.progress > 0.6 && live.progress < 0.7)
    }
}

@Suite("Base32")
struct Base32Tests {
    @Test("Round trips RFC 4648 examples")
    func roundTrip() {
        #expect(Base32.encode(Data("foobar".utf8)) == "MZXW6YTBOI")
        #expect(Base32.decode("MZXW6YTBOI") == Data("foobar".utf8))
    }

    @Test("Tolerates lowercase, spaces, and missing padding")
    func lenient() {
        #expect(Base32.decode("mzxw 6ytb oi") == Data("foobar".utf8))
        #expect(Base32.decode("JBSWY3DPEHPK3PXP") != nil)
    }

    @Test("Rejects out-of-alphabet characters")
    func invalid() {
        #expect(Base32.decode("01890!") == nil)
    }
}

@Suite("otpauth URI")
struct OTPAuthURITests {
    @Test("Parses a full GitHub-style URI")
    func parseFull() throws {
        let uri = try OTPAuthURI(string: "otpauth://totp/GitHub:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA256&digits=8&period=60")
        #expect(uri.issuer == "GitHub")
        #expect(uri.accountName == "alice@example.com")
        #expect(uri.base32Secret == "JBSWY3DPEHPK3PXP")
        #expect(uri.parameters.algorithm == .sha256)
        #expect(uri.parameters.digits == 8)
        #expect(uri.parameters.period == 60)
    }

    @Test("Applies RFC defaults when fields are omitted")
    func parseDefaults() throws {
        let uri = try OTPAuthURI(string: "otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP")
        #expect(uri.issuer == "")
        #expect(uri.accountName == "alice")
        #expect(uri.parameters.algorithm == .sha1)
        #expect(uri.parameters.digits == 6)
        #expect(uri.parameters.period == 30)
    }

    @Test("Round-trips through uriString()")
    func roundTrip() throws {
        let original = try OTPAuthURI(string: "otpauth://totp/GitHub:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA512&digits=7&period=45")
        let reparsed = try OTPAuthURI(string: original.uriString())
        #expect(reparsed == original)
    }

    @Test("Rejects non-otpauth and missing-secret URIs")
    func rejects() {
        #expect(throws: AppError.self) { try OTPAuthURI(string: "https://example.com") }
        #expect(throws: AppError.self) { try OTPAuthURI(string: "otpauth://totp/x?issuer=y") }
    }
}
