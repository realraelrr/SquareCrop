@testable import SquareCrop
import CoreImage
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import XCTest

final class SquareCropImageTests: XCTestCase {
  func testDataDownsamplesLargeInputAndRejectsCorruptData() throws {
    let raw = try colorImage(width: 4096, height: 2048)
    let source = try SquareCropSource(data: encoded(raw, orientation: 1))
    XCTAssertEqual(source.pixelSize, CGSize(width: 2048, height: 1024))
    XCTAssertThrowsError(try SquareCropSource(data: Data("not-an-image".utf8))) {
      XCTAssertEqual($0 as? SquareCropError, .invalidImageData)
    }
    XCTAssertThrowsError(try SquareCropSource(image: UIImage(ciImage: CIImage(color: .red)))) {
      XCTAssertEqual($0 as? SquareCropError, .unsupportedSource)
    }
  }

  func testDataUsesDeclaredNonzeroHEIFPrimaryImage() throws {
    // ImageIO-created HEIC: red image at index 0, blue primary image at index 1.
    // Keep the tiny fixture fixed so encoder ordering cannot mask this regression.
    let data = try XCTUnwrap(Data(base64Encoded: """
      AAAAIGZ0eXBoZWljAAAAAG1pZjFNaUhFbWlhZmhlaWMAAAGxbWV0YQAAAAAAAAAhaGRscgAAAAAAAAAAcGljdAAAAAAAAAAA
      AAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEAAAAOcGl0bQAAAAAAAgAAADhpaW5mAAAAAAACAAAA
      FWluZmUCAAAAAAEAAGh2YzEAAAAAFWluZmUCAAAAAAIAAGh2YzEAAAAA7mlwcnAAAADEaXBjbwAAABNjb2xybmNseAACAAIA
      BoAAAAAMY2xsaQDLAEAAAAAUaXNwZQAAAAAAAABgAAAAQAAAAAlpcm90AAAAABBwaXhpAAAAAAMICAgAAABwaHZjQwEECAAA
      AL4IAAAAAB7wAPz/+PgAAAsDoAABABdAAQwB//8ECAAAAwC+CAAAAwAAHhcCQKEAAQAiQgEBBAgAAAMAvggAAAMAAB6QAoQI
      OBB8QL3IsKm4EBAwBKIAAQAJRAHAYNQQgqkgAAAAImlwbWEAAAAAAAAAAgABBoECAwWGhAACBoECAwWGhAAAACxpbG9jAAAA
      AEQAAAIAAQAAAAEAAAHhAAAAwQACAAAAAQAAAqIAAADJAAAAAW1kYXQAAAAAAAABmgAAAL0oAa6EWEAu/H+7C9//9xe3PxSK
      kZGRkZSMjIyMjIyKqf//nNZf//uL272TkSJEiRLFixYsWLE07/8VNgBd5qnMlyaYeHAHAHAHAHF/F/F/F/F/F/F/GG6mIPvF
      72Pjxj9RxPDm/YYgABAT5501UcmioqKipq6urq6urqte/4yQALNfquaowGjRo0ajx48ePHjpYnSgv//2S+xPrL0dyNyNyNyN
      yWyWyWyWyWyWyWyQJ/TV0QfAuwbFPblt3sMAAADFKAGuhFxALvx/uwvf//uAFuhaJLlYnYnYnYnYzQzQzQzQzQzQzQqx//+c
      0WAE/qb9Q/RvmXhXhXhXhXhrhrhrhrhrhrhrhdO//FZP//0nIXDDDDDDyyyyyyy63UxB94vex8eMfqOJ4c37DEAAIDPHp06Z
      MIjgfgfgfgfg/w/w/w/w/w/w/wit/xqH//+e9zscv2Mp2J2J2J2J3j3j3j3j3j3j3j2TE6PmAR3Rt5JJJJJJtttttttYn9NX
      RB8C7BjFPblt3sM=
      """, options: .ignoreUnknownCharacters))
    let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    XCTAssertEqual(CGImageSourceGetCount(imageSource), 2)
    XCTAssertEqual(CGImageSourceGetPrimaryImageIndex(imageSource), 1)

    let source = try SquareCropSource(data: data)
    XCTAssertEqual(source.pixelSize, CGSize(width: 96, height: 64))
    assertPixel(pixel(source.cgImage, CGPoint(x: 0.5, y: 0.5)), approximately: [0, 0, 255, 255], tolerance: 15)
    let output = try XCTUnwrap(source.render(outputPixelSide: 64).cgImage)
    assertPixel(pixel(output, CGPoint(x: 0.5, y: 0.5)), approximately: [0, 0, 255, 255], tolerance: 15)
  }

  func testAllEightEXIFAndUIImageOrientationsAgreeAtScaleTwoAndThree() throws {
    let raw = try colorImage(width: 120, height: 80)
    let orientations: [UIImage.Orientation] = [.up, .upMirrored, .down, .downMirrored, .leftMirrored, .right, .rightMirrored, .left]
    for (index, orientation) in orientations.enumerated() {
      let dataSource = try SquareCropSource(data: encoded(raw, orientation: index + 1))
      let swapsAxes = index >= 4
      XCTAssertEqual(dataSource.pixelSize, swapsAxes ? CGSize(width: 80, height: 120) : CGSize(width: 120, height: 80))
      for scale in [CGFloat(2), 3] {
        let imageSource = try SquareCropSource(image: UIImage(cgImage: raw, scale: scale, orientation: orientation))
        XCTAssertEqual(imageSource.pixelSize, dataSource.pixelSize)
        for point in [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.2), CGPoint(x: 0.2, y: 0.8), CGPoint(x: 0.8, y: 0.8)] {
          assertPixel(pixel(imageSource.cgImage, point), approximately: pixel(dataSource.cgImage, point), tolerance: 12)
        }
        let exported = try imageSource.render(outputPixelSide: 64)
        XCTAssertEqual(exported.scale, 1)
        XCTAssertEqual(exported.imageOrientation, .up)
        XCTAssertEqual(exported.size, CGSize(width: 64, height: 64))
      }
    }
  }

  func testLargeRotatedMirroredUIImagePreparationStaysWithinPixelBudget() throws {
    let raw = try colorImage(width: 4096, height: 2048)
    for orientation in [UIImage.Orientation.right, .leftMirrored] {
      let prepared = try SquareCropSource(image: UIImage(cgImage: raw, scale: 3, orientation: orientation))
      XCTAssertEqual(prepared.pixelSize, CGSize(width: 1024, height: 2048))
    }
  }

  func testOutputSideValidationOpaqueSquareAndSourceIdentity() throws {
    let source = try SquareCropSource(image: UIImage(cgImage: colorImage(width: 120, height: 80)))
    XCTAssertEqual(source.id, source.id)
    let separate = try SquareCropSource(image: UIImage(cgImage: source.cgImage))
    XCTAssertNotEqual(source.id, separate.id)
    for invalid in [Int.min, -1, 0, 2049, Int.max] {
      XCTAssertThrowsError(try source.render(outputPixelSide: invalid)) {
        XCTAssertEqual($0 as? SquareCropError, .invalidOutputSize)
      }
    }
    for side in [1, 512, 2048] {
      let output = try source.render(outputPixelSide: side)
      XCTAssertEqual(output.cgImage?.width, side)
      XCTAssertEqual(output.cgImage?.height, side)
      XCTAssertEqual(output.scale, 1)
      XCTAssertEqual(output.imageOrientation, .up)
      XCTAssertEqual(pixel(try XCTUnwrap(output.cgImage), CGPoint(x: 0.01, y: 0.01))[3], 255)
    }
  }

  @MainActor
  func testPreviewAndOutputUseSamePreparedSourceAcrossViewportSizes() throws {
    let source = try SquareCropSource(image: UIImage(cgImage: colorImage(width: 120, height: 80)))
    for crop in [SquareCropState(), try SquareCropState(zoom: 2, offsetX: 0.3, offsetY: -0.2), try SquareCropState(zoom: 4, offsetX: -1, offsetY: 1)] {
      let output = try XCTUnwrap(source.render(crop: crop, outputPixelSide: 236).cgImage)
      for side in [CGFloat(236), 320] {
        let canvas = try SquareCropView(
          source: source, crop: .constant(crop), viewportSide: side,
          style: .init(background: .black, border: .clear, cornerRadius: 0, showsCircularGuide: false)
        )
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        let preview = try XCTUnwrap(renderer.uiImage?.cgImage)
        XCTAssertEqual(preview.width, Int(side))
        // Stay inside the color blocks: a boundary can use different sampling
        // filters in UIKit export and SwiftUI's resized image.
        for point in [CGPoint(x: 0.17, y: 0.17), CGPoint(x: 0.73, y: 0.17), CGPoint(x: 0.17, y: 0.73), CGPoint(x: 0.73, y: 0.73)] {
          assertPixel(pixel(preview, point), approximately: pixel(output, point), tolerance: 3)
        }
      }
    }
  }

  @MainActor
  func testInvalidViewportSizesReturnTypedErrors() throws {
    let source = try SquareCropSource(image: UIImage(cgImage: colorImage(width: 120, height: 80)))
    for side in [CGFloat.zero, -1, .nan, .infinity, -.infinity] {
      XCTAssertThrowsError(try SquareCropView(source: source, crop: .constant(.init()), viewportSide: side)) {
        XCTAssertEqual($0 as? SquareCropError, .invalidViewportSize)
      }
    }
  }

  private func colorImage(width: Int, height: Int) throws -> CGImage {
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let colors: [CGColor] = [UIColor.red.cgColor, UIColor.green.cgColor, UIColor.blue.cgColor, UIColor.yellow.cgColor]
    for index in 0..<4 {
      context.setFillColor(colors[index])
      context.fill(CGRect(x: (index % 2) * width / 2, y: (index / 2) * height / 2, width: width / 2, height: height / 2))
    }
    return try XCTUnwrap(context.makeImage())
  }

  private func encoded(_ image: CGImage, orientation: Int) throws -> Data {
    let data = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation, kCGImageDestinationLossyCompressionQuality: 1] as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }

  private func pixel(_ image: CGImage, _ point: CGPoint) -> [Int] {
    var bytes = [UInt8](repeating: 0, count: 4)
    let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: -floor(point.x * CGFloat(image.width)), y: -floor(point.y * CGFloat(image.height)), width: CGFloat(image.width), height: CGFloat(image.height)))
    return bytes.map(Int.init)
  }

  private func assertPixel(_ actual: [Int], approximately expected: [Int], tolerance: Int, file: StaticString = #filePath, line: UInt = #line) {
    for channel in 0..<4 { XCTAssertLessThanOrEqual(abs(actual[channel] - expected[channel]), tolerance, file: file, line: line) }
  }
}
