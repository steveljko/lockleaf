import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Generates and decodes QR codes using Core Image, with no third-party deps.
enum QRCode {

    /// Render `string` as a crisp QR `NSImage` of roughly `size` points.
    static func image(from string: String, size: CGFloat = 220) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }

    /// Extract every QR payload found in an image (a screenshot may contain one).
    static func decode(_ image: NSImage) -> [String] {
        guard let tiff = image.tiffRepresentation,
              let ciImage = CIImage(data: tiff) else { return [] }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) ?? []
        return features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }
    }
}
