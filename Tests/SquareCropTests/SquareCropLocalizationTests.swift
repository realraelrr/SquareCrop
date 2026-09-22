@testable import SquareCrop
import XCTest

final class SquareCropLocalizationTests: XCTestCase {
  func testSixLocaleResourcesHaveCompleteKeysAndZoomPlaceholders() throws {
    let locales = ["en", "zh-Hans", "zh-Hant", "ja", "ko", "es"]
    let keys: Set<String> = ["crop.preview", "crop.center", "crop.move_left", "crop.move_right", "crop.move_up", "crop.move_down", "crop.zoom.value"]
    XCTAssertEqual(Set(Bundle.module.localizations), Set(locales))
    for locale in locales {
      let path = try XCTUnwrap(Bundle.module.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: locale))
      let values = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: path)), format: nil) as? [String: String])
      XCTAssertEqual(Set(values.keys), keys)
      XCTAssertTrue(values.values.allSatisfy { !$0.isEmpty })
      XCTAssertTrue(try XCTUnwrap(values["crop.zoom.value"]).contains("%lld%%"))
    }
  }

  func testExplicitLocaleUsesPackageTranslations() {
    let english = SquareCropAccessibility.localized(locale: Locale(identifier: "en"))
    XCTAssertEqual(english.label, "Photo crop preview")
    XCTAssertEqual(english.center, "Center photo")
    let chinese = SquareCropAccessibility.localized(locale: Locale(identifier: "zh-Hans"))
    XCTAssertEqual(chinese.label, "照片裁剪预览")
    XCTAssertEqual(chinese.center, "将照片居中")
  }
}
