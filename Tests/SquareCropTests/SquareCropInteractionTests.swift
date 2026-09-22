@testable import SquareCrop
import XCTest

final class SquareCropInteractionTests: XCTestCase {
  private let size = CGSize(width: 1000, height: 500)

  func testInterleavedDragPinchDragPreservesBothAcceptedComponents() throws {
    let context = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 236)
    var interaction = SquareCropInteraction()
    interaction.activate(context)
    var crop = try SquareCropState(zoom: 2)
    crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 23.6, height: 0), context: context, crop: crop, imageSize: size))
    crop = try XCTUnwrap(interaction.magnify(magnification: 1.5, context: context, crop: crop, imageSize: size))
    crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 47.2, height: 0), context: context, crop: crop, imageSize: size))
    XCTAssertEqual(crop.zoom, 3)
    XCTAssertEqual(crop.offsetX, 0.2, accuracy: 0.000_001)
    crop = try XCTUnwrap(interaction.magnify(magnification: 1.75, context: context, crop: crop, imageSize: size))
    XCTAssertEqual(crop.zoom, 3.5)
    XCTAssertEqual(crop.offsetX, 0.2, accuracy: 0.000_001)
  }

  func testPinchDragPinchAndBothEndingOrdersPreserveComposition() throws {
    for dragEndsFirst in [true, false] {
      let context = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 236)
      var interaction = SquareCropInteraction()
      interaction.activate(context)
      var crop = try SquareCropState(zoom: 2)
      crop = try XCTUnwrap(interaction.magnify(magnification: 1.2, context: context, crop: crop, imageSize: size))
      crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 23.6, height: 0), context: context, crop: crop, imageSize: size))
      crop = try XCTUnwrap(interaction.magnify(magnification: 1.5, context: context, crop: crop, imageSize: size))
      XCTAssertEqual(crop.zoom, 3)
      XCTAssertEqual(crop.offsetX, 0.1, accuracy: 0.000_001)
      if dragEndsFirst {
        interaction.endDrag(context)
        crop = try XCTUnwrap(interaction.magnify(magnification: 1.75, context: context, crop: crop, imageSize: size))
        interaction.endMagnification(context)
        XCTAssertEqual(crop.zoom, 3.5)
      } else {
        interaction.endMagnification(context)
        crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 47.2, height: 0), context: context, crop: crop, imageSize: size))
        interaction.endDrag(context)
        XCTAssertEqual(crop.offsetX, 0.2, accuracy: 0.000_001)
      }
      let before = crop
      crop = try XCTUnwrap(interaction.drag(translation: .zero, context: context, crop: crop, imageSize: size))
      XCTAssertEqual(crop, before)
    }
  }

  func testPinchClampRebasesActiveDragOnBothAxesAndEndingOrders() throws {
    let square = CGSize(width: 1000, height: 1000)
    for dragEndsFirst in [true, false] {
      let context = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 236)
      var interaction = SquareCropInteraction()
      interaction.activate(context)
      var crop = try SquareCropState(zoom: 4, offsetX: 1.4, offsetY: -1.4)
      crop = try XCTUnwrap(interaction.drag(
        translation: CGSize(width: 11.8, height: -11.8), context: context, crop: crop, imageSize: square
      ))
      XCTAssertEqual(crop.offsetX, 1.45, accuracy: 0.000_001)
      XCTAssertEqual(crop.offsetY, -1.45, accuracy: 0.000_001)
      crop = try XCTUnwrap(interaction.magnify(
        magnification: 0.5, context: context, crop: crop, imageSize: square
      ))
      XCTAssertEqual(crop.zoom, 2)
      XCTAssertEqual(crop.offsetX, 0.5)
      XCTAssertEqual(crop.offsetY, -0.5)
      crop = try XCTUnwrap(interaction.drag(
        translation: CGSize(width: -23.6, height: 23.6), context: context, crop: crop, imageSize: square
      ))
      XCTAssertEqual(crop.offsetX, 0.35, accuracy: 0.000_001)
      XCTAssertEqual(crop.offsetY, -0.35, accuracy: 0.000_001)

      if dragEndsFirst {
        interaction.endDrag(context)
        crop = try XCTUnwrap(interaction.magnify(
          magnification: 0.4, context: context, crop: crop, imageSize: square
        ))
        interaction.endMagnification(context)
        XCTAssertEqual(crop.zoom, 1.6)
        XCTAssertEqual(crop.offsetX, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(crop.offsetY, -0.3, accuracy: 0.000_001)
      } else {
        interaction.endMagnification(context)
        crop = try XCTUnwrap(interaction.drag(
          translation: CGSize(width: -47.2, height: 47.2), context: context, crop: crop, imageSize: square
        ))
        interaction.endDrag(context)
        XCTAssertEqual(crop.zoom, 2)
        XCTAssertEqual(crop.offsetX, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(crop.offsetY, -0.25, accuracy: 0.000_001)
      }
      let accepted = crop
      crop = try XCTUnwrap(interaction.drag(
        translation: .zero, context: context, crop: crop, imageSize: square
      ))
      XCTAssertEqual(crop, accepted)
    }
  }

  func testResizeSourceReplacementAndDisappearRejectLateUpdates() throws {
    let sourceID = UUID()
    let old = SquareCropInteraction.Context(sourceID: sourceID, viewportSide: 236)
    let resized = SquareCropInteraction.Context(sourceID: sourceID, viewportSide: 472)
    let replaced = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 472)
    var interaction = SquareCropInteraction()
    interaction.activate(old)
    var crop = try SquareCropState(zoom: 2)
    crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 23.6, height: 0), context: old, crop: crop, imageSize: size))
    let rect = crop.sourceRect(imageSize: size)
    interaction.activate(resized)
    XCTAssertNil(interaction.drag(translation: CGSize(width: 99, height: 0), context: old, crop: crop, imageSize: size))
    XCTAssertEqual(crop.sourceRect(imageSize: size), rect)
    crop = try XCTUnwrap(interaction.drag(translation: .zero, context: resized, crop: crop, imageSize: size))
    XCTAssertEqual(crop.sourceRect(imageSize: size), rect)
    interaction.activate(replaced)
    XCTAssertNil(interaction.magnify(magnification: 2, context: resized, crop: crop, imageSize: size))
    interaction.deactivate(resized) // A late disappearance cannot cancel the new source.
    XCTAssertNotNil(interaction.magnify(magnification: 1, context: replaced, crop: crop, imageSize: size))
    interaction.deactivate(replaced)
    XCTAssertNil(interaction.drag(translation: .zero, context: replaced, crop: crop, imageSize: size))
  }

  func testInvalidEventsDoNotPoisonNextValidGestureBaseline() throws {
    let context = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 236)
    var interaction = SquareCropInteraction()
    interaction.activate(context)
    let crop = try SquareCropState(zoom: 2)
    XCTAssertNil(interaction.drag(translation: CGSize(width: CGFloat.nan, height: 0), context: context, crop: crop, imageSize: size))
    XCTAssertNil(interaction.magnify(magnification: .infinity, context: context, crop: crop, imageSize: size))
    XCTAssertNil(interaction.magnify(magnification: 0, context: context, crop: crop, imageSize: size))
    let next = try XCTUnwrap(interaction.magnify(magnification: 1.5, context: context, crop: crop, imageSize: size))
    XCTAssertEqual(next.zoom, 3)
  }
}
