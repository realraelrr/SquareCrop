import Foundation

/// Localized defaults can be replaced by the host's established product copy.
public struct SquareCropAccessibility: Sendable {
  public var label: String
  public var center: String
  public var moveLeft: String
  public var moveRight: String
  public var moveUp: String
  public var moveDown: String
  public var zoomValueFormat: String

  public init(
    label: String,
    center: String,
    moveLeft: String,
    moveRight: String,
    moveUp: String,
    moveDown: String,
    zoomValueFormat: String
  ) {
    self.label = label
    self.center = center
    self.moveLeft = moveLeft
    self.moveRight = moveRight
    self.moveUp = moveUp
    self.moveDown = moveDown
    self.zoomValueFormat = zoomValueFormat
  }

  public static func localized(locale: Locale = .current) -> Self {
    // Explicit locale is useful both for an independent host and for verifying
    // the resources in the package bundle actually shipped with that host.
    func string(_ key: String) -> String {
      let available = Bundle.module.localizations
      let preferred = Bundle.preferredLocalizations(from: available, forPreferences: [locale.identifier])
      let localizedBundle = preferred.first
        .flatMap { Bundle.module.path(forResource: $0, ofType: "lproj") }
        .flatMap(Bundle.init(path:)) ?? Bundle.module
      return localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }
    return Self(
      label: string("crop.preview"),
      center: string("crop.center"),
      moveLeft: string("crop.move_left"),
      moveRight: string("crop.move_right"),
      moveUp: string("crop.move_up"),
      moveDown: string("crop.move_down"),
      zoomValueFormat: string("crop.zoom.value")
    )
  }
}
