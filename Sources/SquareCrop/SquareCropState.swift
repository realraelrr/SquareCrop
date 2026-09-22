import Foundation

public enum SquareCropError: Error, Equatable, Sendable {
  case invalidImageData
  case unsupportedSource
  case invalidImageSize
  case invalidTransform
  case invalidOutputSize
  case invalidViewportSize
}

/// Offsets are fractions of the square viewport side, positive right/down.
/// A state selects the same source pixels at every viewport size.
public struct SquareCropState: Equatable, Sendable {
  public static let minimumZoom = 1.0
  public static let maximumZoom = 4.0

  public let zoom: Double
  public let offsetX: Double
  public let offsetY: Double

  public init() {
    zoom = 1
    offsetX = 0
    offsetY = 0
  }

  /// Rejects nonfinite input. Finite zoom is limited to 1...4; offsets are
  /// limited to the image bounds when used with a prepared source.
  public init(zoom: Double, offsetX: Double = 0, offsetY: Double = 0) throws {
    guard zoom.isFinite, offsetX.isFinite, offsetY.isFinite else {
      throw SquareCropError.invalidTransform
    }
    self.zoom = min(max(zoom, Self.minimumZoom), Self.maximumZoom)
    self.offsetX = offsetX
    self.offsetY = offsetY
  }

  public func normalized(for source: SquareCropSource) -> Self {
    normalized(imageSize: source.pixelSize)
  }

  func normalized(imageSize: CGSize) -> Self {
    let shortestSide = min(imageSize.width, imageSize.height)
    let maxX = max(0, (imageSize.width / shortestSide * zoom - 1) / 2)
    let maxY = max(0, (imageSize.height / shortestSide * zoom - 1) / 2)
    return Self(
      validZoom: zoom,
      offsetX: min(max(offsetX, -maxX), maxX),
      offsetY: min(max(offsetY, -maxY), maxY)
    )
  }

  func sourceRect(imageSize: CGSize) -> CGRect {
    let normalized = normalized(imageSize: imageSize)
    let side = min(imageSize.width, imageSize.height) / zoom
    return CGRect(
      x: min(max((imageSize.width - side) / 2 - normalized.offsetX * side, 0), imageSize.width - side),
      y: min(max((imageSize.height - side) / 2 - normalized.offsetY * side, 0), imageSize.height - side),
      width: side,
      height: side
    )
  }

  private init(validZoom: Double, offsetX: Double, offsetY: Double) {
    zoom = validZoom
    self.offsetX = offsetX
    self.offsetY = offsetY
  }
}
