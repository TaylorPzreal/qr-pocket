import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

public enum QRRenderer {
    private static let context = CIContext()

    public static func image(for content: String) throws -> NSImage {
        let cgImage = try render(content)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    public static func png(for content: String) throws -> Data {
        let bitmap = NSBitmapImageRep(cgImage: try render(content))
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    private static func render(_ content: String) throws -> CGImage {
        try QRRecord.validateContent(content)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard let code = filter.outputImage else { throw CocoaError(.coderInvalidValue) }
        // Four white modules on every side are required for reliable scanning.
        let extent = code.extent.insetBy(dx: -4, dy: -4)
        let white = CIImage(color: CIColor.white).cropped(to: extent)
        let padded = code.composited(over: white)
        let scale = max(1, ceil(640 / extent.width))
        let scaled = padded.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let image = context.createCGImage(scaled, from: scaled.extent) else {
            throw CocoaError(.coderInvalidValue)
        }
        return image
    }
}
