import Foundation
import ImageIO
import UIKit

/// An immutable, upright, scale-1 source shared by preview and export.
/// Preparation never creates an intermediate full-resolution rendered bitmap.
public struct SquareCropSource: Sendable, Identifiable {
  public static let maximumPixelDimension = 2_048
  public let id: UUID
  public let cgImage: CGImage

  public var pixelSize: CGSize {
    CGSize(width: cgImage.width, height: cgImage.height)
  }

  /// ImageIO applies EXIF orientation while downsampling. This synchronous work
  /// belongs in the caller's image-loading task, never a SwiftUI body/update.
  public init(data: Data) throws {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
      throw SquareCropError.invalidImageData
    }
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: Self.maximumPixelDimension,
      kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
      throw SquareCropError.invalidImageData
    }
    guard image.width > 0, image.height > 0 else {
      throw SquareCropError.invalidImageSize
    }
    cgImage = image
    id = UUID()
  }

  /// Accepts CGImage-backed UIImages, including rotated/mirrored and @2x/@3x
  /// inputs. A CIImage-only UIImage is deliberately unsupported in version 1.
  public init(image: UIImage) throws {
    guard let original = image.cgImage else { throw SquareCropError.unsupportedSource }
    guard original.width > 0, original.height > 0 else { throw SquareCropError.invalidImageSize }
    let swapsAxes: Bool
    switch image.imageOrientation {
    case .left, .leftMirrored, .right, .rightMirrored: swapsAxes = true
    default: swapsAxes = false
    }
    let width = swapsAxes ? original.height : original.width
    let height = swapsAxes ? original.width : original.height
    let ratio = min(1, Double(Self.maximumPixelDimension) / Double(max(width, height)))
    let target = CGSize(
      width: max(1, floor(Double(width) * ratio)),
      height: max(1, floor(Double(height) * ratio))
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = false
    let upright = UIGraphicsImageRenderer(size: target, format: format).image { _ in
      UIImage(cgImage: original, scale: 1, orientation: image.imageOrientation)
        .draw(in: CGRect(origin: .zero, size: target))
    }
    guard let prepared = upright.cgImage else { throw SquareCropError.unsupportedSource }
    cgImage = prepared
    id = UUID()
  }

  public func sourceRect(for crop: SquareCropState) -> CGRect {
    crop.sourceRect(imageSize: pixelSize)
  }

  /// Produces an opaque square with black behind transparent source pixels.
  /// Output is upright, scale 1, and its integer side must be in 1...2048.
  public func render(crop: SquareCropState = .init(), outputPixelSide: Int = 512) throws -> UIImage {
    guard (1...Self.maximumPixelDimension).contains(outputPixelSide) else {
      throw SquareCropError.invalidOutputSize
    }
    let side = CGFloat(outputPixelSide)
    let rect = sourceRect(for: crop)
    let scale = side / rect.width
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
      UIColor.black.setFill()
      UIRectFill(CGRect(x: 0, y: 0, width: side, height: side))
      UIImage(cgImage: cgImage).draw(in: CGRect(
        x: -rect.minX * scale,
        y: -rect.minY * scale,
        width: pixelSize.width * scale,
        height: pixelSize.height * scale
      ))
    }
  }
}
