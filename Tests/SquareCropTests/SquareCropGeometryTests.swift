@testable import SquareCrop
import XCTest

final class SquareCropGeometryTests: XCTestCase {
  func testLandscapePortraitSquareAndExtremeOffsetsStayInsideSource() throws {
    for size in [CGSize(width: 1000, height: 500), CGSize(width: 500, height: 1000), CGSize(width: 700, height: 700)] {
      for zoom in [1.0, 4.0] {
        for offset in [-100.0, 0, 100] {
          let state = try SquareCropState(zoom: zoom, offsetX: offset, offsetY: -offset)
          let rect = state.sourceRect(imageSize: size)
          XCTAssertEqual(rect.width, min(size.width, size.height) / zoom)
          XCTAssertEqual(rect.width, rect.height)
          XCTAssertGreaterThanOrEqual(rect.minX, 0)
          XCTAssertGreaterThanOrEqual(rect.minY, 0)
          XCTAssertLessThanOrEqual(rect.maxX, size.width)
          XCTAssertLessThanOrEqual(rect.maxY, size.height)
        }
      }
    }
  }

  func testViewportResizePreservesSourceRectAndOriginal236PointComposition() throws {
    let size = CGSize(width: 1000, height: 500)
    let state = try SquareCropState(zoom: 1, offsetX: 59.0 / 236)
    XCTAssertEqual(state.sourceRect(imageSize: size), CGRect(x: 125, y: 0, width: 500, height: 500))
    for viewport in [118.0, 236, 320, 472] {
      let displayedOffset = state.offsetX * viewport
      let effectiveScale = viewport / 500
      let sourceX = ((1000 * effectiveScale - viewport) / 2 - displayedOffset) / effectiveScale
      XCTAssertEqual(sourceX, state.sourceRect(imageSize: size).minX, accuracy: 0.000_001)
    }
  }

  func testNonfiniteTransformsAreRejectedAndFiniteZoomIsClamped() throws {
    for bad in [Double.nan, .infinity, -.infinity] {
      XCTAssertThrowsError(try SquareCropState(zoom: bad)) { XCTAssertEqual($0 as? SquareCropError, .invalidTransform) }
      XCTAssertThrowsError(try SquareCropState(zoom: 1, offsetX: bad))
      XCTAssertThrowsError(try SquareCropState(zoom: 1, offsetY: bad))
    }
    XCTAssertEqual(try SquareCropState(zoom: -2).zoom, 1)
    XCTAssertEqual(try SquareCropState(zoom: 10).zoom, 4)
  }

  func testAccessibilityCenterMovesAndZoomMatchOriginalIncrements() throws {
    let size = CGSize(width: 1000, height: 1000)
    var state = try SquareCropState(zoom: 2)
    state = state.applying(.right, imageSize: size).applying(.down, imageSize: size)
    XCTAssertEqual(state.offsetX * 236, 18.88, accuracy: 0.000_001)
    XCTAssertEqual(state.offsetY, 0.08)
    state = state.applying(.left, imageSize: size).applying(.up, imageSize: size)
    XCTAssertEqual(state.offsetX, 0)
    XCTAssertEqual(state.offsetY, 0)
    state = state.applying(.zoomIn, imageSize: size)
    XCTAssertEqual(state.zoom, 2.25)
    state = state.applying(.zoomOut, imageSize: size).applying(.right, imageSize: size)
    state = state.applying(.center, imageSize: size)
    XCTAssertEqual(state, try SquareCropState(zoom: 2))
    for _ in 0..<30 { state = state.applying(.zoomOut, imageSize: size) }
    XCTAssertEqual(state, SquareCropState())
    for _ in 0..<30 { state = state.applying(.zoomIn, imageSize: size) }
    XCTAssertEqual(state.zoom, 4)
  }
}
