import SwiftUI
import UIKit

public struct SquareCropStyle {
  public var background: Color
  public var border: Color
  public var cornerRadius: CGFloat
  public var showsCircularGuide: Bool

  public init(
    background: Color = .black.opacity(0.92),
    border: Color = .gray.opacity(0.48),
    cornerRadius: CGFloat = 18,
    showsCircularGuide: Bool = true
  ) {
    self.background = background
    self.border = border
    self.cornerRadius = cornerRadius
    self.showsCircularGuide = showsCircularGuide
  }
}

/// A square crop canvas without navigation, photo permissions or save controls.
/// The viewport side must be finite and positive. Resizing does not change crop.
public struct SquareCropView: View {
  private let source: SquareCropSource
  @Binding private var crop: SquareCropState
  private let viewportSide: CGFloat
  private let style: SquareCropStyle
  private let accessibility: SquareCropAccessibility
  @State private var interaction = SquareCropInteraction()
  @GestureState private var isDragging = false
  @GestureState private var isMagnifying = false

  public init(
    source: SquareCropSource,
    crop: Binding<SquareCropState>,
    viewportSide: CGFloat = 236,
    style: SquareCropStyle = .init(),
    accessibility: SquareCropAccessibility = .localized()
  ) throws {
    guard viewportSide.isFinite, viewportSide > 0 else {
      throw SquareCropError.invalidViewportSize
    }
    self.source = source
    _crop = crop
    self.viewportSide = viewportSide
    self.style = style
    self.accessibility = accessibility
  }

  public var body: some View {
    let context = SquareCropInteraction.Context(sourceID: source.id, viewportSide: viewportSide)
    let normalized = crop.normalized(for: source)
    let scale = viewportSide / min(source.pixelSize.width, source.pixelSize.height) * normalized.zoom

    ZStack {
      style.background
      Image(uiImage: UIImage(cgImage: source.cgImage))
        .resizable()
        .scaledToFill()
        .frame(width: source.pixelSize.width * scale, height: source.pixelSize.height * scale)
        .offset(x: normalized.offsetX * viewportSide, y: normalized.offsetY * viewportSide)
    }
    .frame(width: viewportSide, height: viewportSide)
    .clipped()
    .overlay {
      if style.showsCircularGuide { SquareCropCircularGuide() }
    }
    .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        .stroke(style.border, lineWidth: 1)
    }
    .contentShape(Rectangle())
    .gesture(dragGesture(context))
    .simultaneousGesture(magnificationGesture(context))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(accessibility.label))
    .accessibilityValue(Text(String.localizedStringWithFormat(
      accessibility.zoomValueFormat, Int64((normalized.zoom * 100).rounded())
    )))
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: apply(.zoomIn)
      case .decrement: apply(.zoomOut)
      @unknown default: break
      }
    }
    .accessibilityAction(named: Text(accessibility.center)) { apply(.center) }
    .accessibilityAction(named: Text(accessibility.moveLeft)) { apply(.left) }
    .accessibilityAction(named: Text(accessibility.moveRight)) { apply(.right) }
    .accessibilityAction(named: Text(accessibility.moveUp)) { apply(.up) }
    .accessibilityAction(named: Text(accessibility.moveDown)) { apply(.down) }
    .id(context)
    .onAppear { interaction.activate(context) }
    .onDisappear { interaction.deactivate(context) }
    .onChange(of: context) { _, context in interaction.activate(context) }
    .onChange(of: isDragging) { _, active in
      if !active { interaction.endDrag(context) }
    }
    .onChange(of: isMagnifying) { _, active in
      if !active { interaction.endMagnification(context) }
    }
  }

  private func dragGesture(_ context: SquareCropInteraction.Context) -> some Gesture {
    DragGesture()
      .updating($isDragging) { _, active, _ in active = true }
      .onChanged { value in
        if let next = interaction.drag(
          translation: value.translation, context: context, crop: crop, imageSize: source.pixelSize
        ) { crop = next }
      }
      .onEnded { _ in interaction.endDrag(context) }
  }

  private func magnificationGesture(_ context: SquareCropInteraction.Context) -> some Gesture {
    MagnificationGesture()
      .updating($isMagnifying) { _, active, _ in active = true }
      .onChanged { value in
        if let next = interaction.magnify(
          magnification: Double(value), context: context, crop: crop, imageSize: source.pixelSize
        ) { crop = next }
      }
      .onEnded { _ in interaction.endMagnification(context) }
  }

  private func apply(_ action: SquareCropAccessibilityAction) {
    crop = crop.applying(action, imageSize: source.pixelSize)
  }
}

enum SquareCropAccessibilityAction {
  case center, left, right, up, down, zoomIn, zoomOut
}

extension SquareCropState {
  func applying(_ action: SquareCropAccessibilityAction, imageSize: CGSize) -> Self {
    let current = normalized(imageSize: imageSize)
    var zoom = current.zoom
    var x = current.offsetX
    var y = current.offsetY
    switch action {
    case .center: x = 0; y = 0
    case .left: x -= 0.08
    case .right: x += 0.08
    case .up: y -= 0.08
    case .down: y += 0.08
    case .zoomIn: zoom += 0.25
    case .zoomOut: zoom -= 0.25
    }
    // These bounded increments of already finite values cannot fail validation.
    return (try? Self(zoom: zoom, offsetX: x, offsetY: y))?.normalized(imageSize: imageSize) ?? current
  }
}

private struct SquareCropCircularGuide: View {
  var body: some View {
    GeometryReader { proxy in
      let rect = CGRect(origin: .zero, size: proxy.size)
      ZStack {
        Path { path in
          path.addRect(rect)
          path.addEllipse(in: rect.insetBy(dx: 1, dy: 1))
        }
        .fill(Color.black.opacity(0.38), style: FillStyle(eoFill: true))
        Circle()
          .stroke(
            Color.white.opacity(0.96),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 5])
          )
          .shadow(color: .black.opacity(0.38), radius: 4, y: 2)
          .padding(1)
      }
    }
    .allowsHitTesting(false)
  }
}
