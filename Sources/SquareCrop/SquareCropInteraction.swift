import Foundation

/// Local gesture bookkeeping: each gesture owns only its transform component.
/// External effective crop changes become new anchors for unprocessed movement.
/// Identity/viewport changes terminate the recognizers and invalidate callbacks.
struct SquareCropInteraction {
  struct Context: Hashable {
    let sourceID: UUID
    let viewportSide: CGFloat
  }

  private(set) var context: Context?
  private var dragStart: (offset: CGPoint, translation: CGSize)?
  private var zoomStart: (zoom: Double, magnification: Double)?
  private var lastOutput: SquareCropState?
  private var lastDragTranslation: CGSize?
  private var lastMagnification: Double?

  mutating func activate(_ context: Context) {
    self.context = context
    dragStart = nil
    zoomStart = nil
    lastOutput = nil
    lastDragTranslation = nil
    lastMagnification = nil
  }

  mutating func deactivate(_ context: Context) {
    guard self.context == context else { return }
    self.context = nil
    dragStart = nil
    zoomStart = nil
    lastOutput = nil
    lastDragTranslation = nil
    lastMagnification = nil
  }

  mutating func drag(
    translation: CGSize,
    context: Context,
    crop: SquareCropState,
    imageSize: CGSize
  ) -> SquareCropState? {
    guard self.context == context,
      context.viewportSide.isFinite, context.viewportSide > 0,
      translation.width.isFinite, translation.height.isFinite
    else { return nil }
    let current = crop.normalized(imageSize: imageSize)
    rebaseIfNeeded(for: current)
    let start = dragStart ?? (offset: CGPoint(x: current.offsetX, y: current.offsetY), translation: CGSize.zero)
    guard let result = try? SquareCropState(
      zoom: current.zoom,
      offsetX: start.offset.x + (translation.width - start.translation.width) / context.viewportSide,
      offsetY: start.offset.y + (translation.height - start.translation.height) / context.viewportSide
    ) else { return nil }
    dragStart = start
    lastDragTranslation = translation
    let accepted = result.normalized(imageSize: imageSize)
    lastOutput = accepted
    return accepted
  }

  mutating func magnify(
    magnification: Double,
    context: Context,
    crop: SquareCropState,
    imageSize: CGSize
  ) -> SquareCropState? {
    guard self.context == context, magnification.isFinite, magnification > 0 else { return nil }
    let current = crop.normalized(imageSize: imageSize)
    rebaseIfNeeded(for: current)
    let start = zoomStart ?? (zoom: current.zoom, magnification: 1.0)
    guard let result = try? SquareCropState(
      zoom: start.zoom * (magnification / start.magnification),
      offsetX: current.offsetX,
      offsetY: current.offsetY
    ) else { return nil }
    zoomStart = start
    lastMagnification = magnification
    let accepted = result.normalized(imageSize: imageSize)
    if let dragStart {
      // A smaller zoom can move the accepted image offset to a new edge.
      // Carry that correction into the active drag's cumulative baseline.
      self.dragStart = (
        offset: CGPoint(
          x: dragStart.offset.x + accepted.offsetX - current.offsetX,
          y: dragStart.offset.y + accepted.offsetY - current.offsetY
        ),
        translation: dragStart.translation
      )
    }
    lastOutput = accepted
    return accepted
  }

  private mutating func rebaseIfNeeded(for crop: SquareCropState) {
    guard let lastOutput, crop != lastOutput else { return }
    // Re-anchor both active gestures before either can consume a new sample.
    // Preserve each gesture's last processed sample, including clamped events.
    if let lastDragTranslation {
      dragStart = (CGPoint(x: crop.offsetX, y: crop.offsetY), lastDragTranslation)
    }
    if let lastMagnification {
      zoomStart = (crop.zoom, lastMagnification)
    }
  }

  mutating func endDrag(_ context: Context) {
    guard self.context == context else { return }
    dragStart = nil
    lastDragTranslation = nil
  }

  mutating func endMagnification(_ context: Context) {
    guard self.context == context else { return }
    zoomStart = nil
    lastMagnification = nil
  }
}
