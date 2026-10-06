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

  func testExternalCropKeepsUnprocessedMovementForBothCallbackAndEndingOrders() throws {
    for dragRunsFirst in [true, false] {
      for dragEndsFirst in [true, false] {
        let context = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 100)
        var interaction = SquareCropInteraction()
        interaction.activate(context)
        var crop = try SquareCropState(zoom: 2)
        crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 10, height: -5), context: context, crop: crop, imageSize: size))
        crop = try XCTUnwrap(interaction.magnify(magnification: 1.2, context: context, crop: crop, imageSize: size))
        crop = try SquareCropState(zoom: 1.5, offsetX: 0.2, offsetY: -0.1)

        if dragRunsFirst {
          crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 20, height: -15), context: context, crop: crop, imageSize: size))
          crop = try XCTUnwrap(interaction.magnify(magnification: 1.4, context: context, crop: crop, imageSize: size))
        } else {
          crop = try XCTUnwrap(interaction.magnify(magnification: 1.4, context: context, crop: crop, imageSize: size))
          crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 20, height: -15), context: context, crop: crop, imageSize: size))
        }
        XCTAssertEqual(crop.zoom, 1.75, accuracy: 0.000_001)
        XCTAssertEqual(crop.offsetX, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(crop.offsetY, -0.2, accuracy: 0.000_001)

        if dragEndsFirst {
          interaction.endDrag(context)
          crop = try XCTUnwrap(interaction.magnify(magnification: 1.6, context: context, crop: crop, imageSize: size))
          interaction.endMagnification(context)
          XCTAssertEqual(crop.zoom, 2, accuracy: 0.000_001)
          XCTAssertEqual(crop.offsetX, 0.3, accuracy: 0.000_001)
          XCTAssertEqual(crop.offsetY, -0.2, accuracy: 0.000_001)
        } else {
          interaction.endMagnification(context)
          crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 30, height: -25), context: context, crop: crop, imageSize: size))
          interaction.endDrag(context)
          XCTAssertEqual(crop.zoom, 1.75, accuracy: 0.000_001)
          XCTAssertEqual(crop.offsetX, 0.4, accuracy: 0.000_001)
          XCTAssertEqual(crop.offsetY, -0.3, accuracy: 0.000_001)
        }
        let accepted = crop
        crop = try XCTUnwrap(interaction.drag(translation: .zero, context: context, crop: crop, imageSize: size))
        XCTAssertEqual(crop, accepted)
      }
    }
  }

  func testExternalCropWithRepeatedSamplesDoesNotReplayEitherGesture() throws {
    for dragRunsFirst in [true, false] {
      let context = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 100)
      var interaction = SquareCropInteraction()
      interaction.activate(context)
      var crop = try SquareCropState(zoom: 2)
      crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 10, height: -5), context: context, crop: crop, imageSize: size))
      crop = try XCTUnwrap(interaction.magnify(magnification: 1.2, context: context, crop: crop, imageSize: size))
      let external = try SquareCropState(zoom: 1.5, offsetX: 0.2, offsetY: 0.1)
      crop = external
      if dragRunsFirst {
        crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 10, height: -5), context: context, crop: crop, imageSize: size))
        XCTAssertEqual(crop, external)
        crop = try XCTUnwrap(interaction.magnify(magnification: 1.2, context: context, crop: crop, imageSize: size))
      } else {
        crop = try XCTUnwrap(interaction.magnify(magnification: 1.2, context: context, crop: crop, imageSize: size))
        XCTAssertEqual(crop, external)
        crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 10, height: -5), context: context, crop: crop, imageSize: size))
      }
      XCTAssertEqual(crop, external)
    }
  }

  func testExternalCropAfterClampingUsesLatestSamplesForBothGestures() throws {
    let square = CGSize(width: 1000, height: 1000)
    for dragRunsFirst in [true, false] {
      let context = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 100)
      var interaction = SquareCropInteraction()
      interaction.activate(context)
      var crop = try SquareCropState(zoom: 2)
      crop = try XCTUnwrap(interaction.magnify(magnification: 3, context: context, crop: crop, imageSize: square))
      crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 200, height: -200), context: context, crop: crop, imageSize: square))
      let clamped = crop
      crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 300, height: -300), context: context, crop: crop, imageSize: square))
      crop = try XCTUnwrap(interaction.magnify(magnification: 4, context: context, crop: crop, imageSize: square))
      XCTAssertEqual(crop, clamped)
      crop = try SquareCropState(zoom: 2, offsetX: 0.2, offsetY: -0.1)

      if dragRunsFirst {
        crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 310, height: -290), context: context, crop: crop, imageSize: square))
        crop = try XCTUnwrap(interaction.magnify(magnification: 4.4, context: context, crop: crop, imageSize: square))
      } else {
        crop = try XCTUnwrap(interaction.magnify(magnification: 4.4, context: context, crop: crop, imageSize: square))
        crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 310, height: -290), context: context, crop: crop, imageSize: square))
      }
      XCTAssertEqual(crop.zoom, 2.2, accuracy: 0.000_001)
      XCTAssertEqual(crop.offsetX, 0.3, accuracy: 0.000_001)
      XCTAssertEqual(crop.offsetY, 0, accuracy: 0.000_001)
    }
  }

  func testSameEffectiveCropPreservesCumulativeBoundaryReversal() throws {
    let square = CGSize(width: 1000, height: 1000)
    let context = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 100)
    var interaction = SquareCropInteraction()
    interaction.activate(context)
    var crop = try SquareCropState(zoom: 2)
    crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 80, height: 0), context: context, crop: crop, imageSize: square))
    XCTAssertEqual(crop.offsetX, 0.5)
    // This raw write normalizes to the same effective crop, so it is not a reset.
    crop = try SquareCropState(zoom: 2, offsetX: 99)
    crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 70, height: 0), context: context, crop: crop, imageSize: square))
    XCTAssertEqual(crop.offsetX, 0.5)
    crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 40, height: 0), context: context, crop: crop, imageSize: square))
    XCTAssertEqual(crop.offsetX, 0.4, accuracy: 0.000_001)
    interaction.endDrag(context)

    crop = try XCTUnwrap(interaction.magnify(magnification: 3, context: context, crop: crop, imageSize: square))
    XCTAssertEqual(crop.zoom, 4)
    crop = try SquareCropState(zoom: 99, offsetX: 0.4)
    crop = try XCTUnwrap(interaction.magnify(magnification: 2.5, context: context, crop: crop, imageSize: square))
    XCTAssertEqual(crop.zoom, 4)
    crop = try XCTUnwrap(interaction.magnify(magnification: 1.5, context: context, crop: crop, imageSize: square))
    XCTAssertEqual(crop.zoom, 3)
  }

  func testExternalCropNormalizesAndInvalidEventsDoNotConsumeMovement() throws {
    let context = SquareCropInteraction.Context(sourceID: UUID(), viewportSide: 100)
    var interaction = SquareCropInteraction()
    interaction.activate(context)
    var crop = try SquareCropState(zoom: 2)
    crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 10, height: -5), context: context, crop: crop, imageSize: size))
    crop = try XCTUnwrap(interaction.magnify(magnification: 1.2, context: context, crop: crop, imageSize: size))
    crop = try SquareCropState(zoom: 99, offsetX: 99, offsetY: -99)
    XCTAssertNil(interaction.drag(translation: CGSize(width: CGFloat.nan, height: 0), context: context, crop: crop, imageSize: size))
    XCTAssertNil(interaction.magnify(magnification: .infinity, context: context, crop: crop, imageSize: size))
    crop = try XCTUnwrap(interaction.drag(translation: CGSize(width: 10, height: -5), context: context, crop: crop, imageSize: size))
    XCTAssertEqual(crop.zoom, 4)
    XCTAssertEqual(crop.offsetX, 3.5)
    XCTAssertEqual(crop.offsetY, -1.5)
    crop = try XCTUnwrap(interaction.magnify(magnification: 1.2, context: context, crop: crop, imageSize: size))
    XCTAssertEqual(crop.zoom, 4)
    XCTAssertEqual(crop.offsetX, 3.5)
    XCTAssertEqual(crop.offsetY, -1.5)
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
