import Foundation

/// Local gesture bookkeeping: each gesture owns only its transform component.
/// Identity/viewport changes terminate the recognizers and invalidate callbacks.
struct SquareCropInteraction {
  struct Context: Hashable {
    let sourceID: UUID
    let viewportSide: CGFloat
  }

  private(set) var context: Context?
  private var dragStart: CGPoint?
  private var zoomStart: Double?

  mutating func activate(_ context: Context) {
    self.context = context
    dragStart = nil
    zoomStart = nil
  }

  mutating func deactivate(_ context: Context) {
    guard self.context == context else { return }
    self.context = nil
    dragStart = nil
    zoomStart = nil
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
    let start = dragStart ?? CGPoint(x: current.offsetX, y: current.offsetY)
    guard let result = try? SquareCropState(
      zoom: current.zoom,
      offsetX: start.x + translation.width / context.viewportSide,
      offsetY: start.y + translation.height / context.viewportSide
    ) else { return nil }
    dragStart = start
    return result.normalized(imageSize: imageSize)
  }

  mutating func magnify(
    magnification: Double,
    context: Context,
    crop: SquareCropState,
    imageSize: CGSize
  ) -> SquareCropState? {
    guard self.context == context, magnification.isFinite, magnification > 0 else { return nil }
    let current = crop.normalized(imageSize: imageSize)
    let start = zoomStart ?? current.zoom
    guard let result = try? SquareCropState(
      zoom: start * magnification,
      offsetX: current.offsetX,
      offsetY: current.offsetY
    ) else { return nil }
    zoomStart = start
    let accepted = result.normalized(imageSize: imageSize)
    if let dragStart {
      // A smaller zoom can move the accepted image offset to a new edge.
      // Carry that correction into the active drag's cumulative baseline.
      self.dragStart = CGPoint(
        x: dragStart.x + accepted.offsetX - current.offsetX,
        y: dragStart.y + accepted.offsetY - current.offsetY
      )
    }
    return accepted
  }

  mutating func endDrag(_ context: Context) {
    guard self.context == context else { return }
    dragStart = nil
  }

  mutating func endMagnification(_ context: Context) {
    guard self.context == context else { return }
    zoomStart = nil
  }
}
