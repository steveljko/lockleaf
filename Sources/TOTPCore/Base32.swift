import Foundation

/// RFC 4648 Base32 (the alphabet used by virtually every authenticator for OTP
/// secrets). Decoding is tolerant of lowercase, spaces, and missing `=` padding,
/// which real-world `otpauth://` URIs frequently omit.
public enum Base32 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    private static let decodeMap: [Character: UInt8] = {
        var map: [Character: UInt8] = [:]
        for (i, c) in alphabet.enumerated() { map[c] = UInt8(i) }
        return map
    }()

    public static func encode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        var output = ""
        var buffer: UInt32 = 0
        var bitsLeft = 0
        for byte in data {
            buffer = (buffer << 8) | UInt32(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                let index = Int((buffer >> UInt32(bitsLeft - 5)) & 0x1F)
                output.append(alphabet[index])
                bitsLeft -= 5
            }
        }
        if bitsLeft > 0 {
            let index = Int((buffer << UInt32(5 - bitsLeft)) & 0x1F)
            output.append(alphabet[index])
        }
        return output
    }

    /// Returns `nil` if the input contains characters outside the alphabet.
    public static func decode(_ string: String) -> Data? {
        let cleaned = string
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")
        guard !cleaned.isEmpty else { return Data() }

        var output = [UInt8]()
        var buffer: UInt32 = 0
        var bitsLeft = 0
        for char in cleaned {
            guard let value = decodeMap[char] else { return nil }
            buffer = (buffer << 5) | UInt32(value)
            bitsLeft += 5
            if bitsLeft >= 8 {
                output.append(UInt8((buffer >> UInt32(bitsLeft - 8)) & 0xFF))
                bitsLeft -= 8
            }
        }
        return Data(output)
    }
}
