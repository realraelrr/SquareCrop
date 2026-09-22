import Foundation
import SquareCrop
import XCTest

final class SquareCropRuntimeResourcesTests: XCTestCase {
  func testEnglishResourcesResolveFromTheConsumedPackage() {
    let text = SquareCropAccessibility.localized(locale: Locale(identifier: "en"))

    XCTAssertEqual(text.label, "Photo crop preview")
    XCTAssertEqual(text.center, "Center photo")
    XCTAssertEqual(text.moveLeft, "Move photo left")
    XCTAssertEqual(text.moveRight, "Move photo right")
    XCTAssertEqual(text.moveUp, "Move photo up")
    XCTAssertEqual(text.moveDown, "Move photo down")
    XCTAssertEqual(text.zoomValueFormat, "Zoom: %lld%%")
    XCTAssertEqual(String(format: text.zoomValueFormat, Int64(150)), "Zoom: 150%")
  }

  func testSimplifiedChineseResourcesResolveFromTheConsumedPackage() {
    let text = SquareCropAccessibility.localized(locale: Locale(identifier: "zh-Hans"))

    XCTAssertEqual(text.label, "照片裁剪预览")
    XCTAssertEqual(text.center, "将照片居中")
    XCTAssertEqual(text.moveLeft, "向左移动照片")
    XCTAssertEqual(text.moveRight, "向右移动照片")
    XCTAssertEqual(text.moveUp, "向上移动照片")
    XCTAssertEqual(text.moveDown, "向下移动照片")
    XCTAssertEqual(text.zoomValueFormat, "缩放：%lld%%")
    XCTAssertEqual(String(format: text.zoomValueFormat, Int64(150)), "缩放：150%")
  }
}
