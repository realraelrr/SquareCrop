import SquareCrop
import SwiftUI
import UIKit

@main
@MainActor
struct SquareCropExampleApp: App {
  private let source = Result {
    try SquareCropSource(image: SquareCropExampleView.sampleImage())
  }

  var body: some Scene {
    WindowGroup {
      SquareCropExampleView(source: source)
    }
  }
}

@MainActor
private struct SquareCropExampleView: View {
  @State private var crop = SquareCropState()
  @State private var output: UIImage?
  @State private var renderFailed = false

  let source: Result<SquareCropSource, Error>

  init(source: Result<SquareCropSource, Error>) {
    self.source = source
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        switch source {
        case .success(let source):
          VStack(spacing: 24) {
            Text("Drag or pinch either preview. Both share one image and one crop, so the framing stays consistent at different sizes.")
              .font(.body)
              .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
              Text("236 pt")
                .font(.headline)
              // This literal is a known finite, positive viewport size.
              try! SquareCropView(source: source, crop: $crop, viewportSide: 236)
            }

            VStack(spacing: 8) {
              Text("320 pt")
                .font(.headline)
              // This literal is a known finite, positive viewport size.
              try! SquareCropView(source: source, crop: $crop, viewportSide: 320)
            }

            Button("Render 512 × 512") {
              do {
                output = try source.render(crop: crop, outputPixelSide: 512)
                renderFailed = false
              } catch {
                renderFailed = true
              }
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)

            if renderFailed {
              Text("The crop could not be rendered. Adjust the crop and try again.")
            }

            if let output {
              Image(uiImage: output)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 236, height: 236)
                .accessibilityLabel("Rendered square crop")
            }
          }
          .padding(16)
          .frame(maxWidth: .infinity)
        case .failure:
          Text("The example image could not be prepared.")
            .padding()
        }
      }
      .navigationTitle("SquareCrop")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  fileprivate static func sampleImage() -> UIImage {
    let size = CGSize(width: 960, height: 640)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
      let context = renderer.cgContext
      UIColor(red: 0.12, green: 0.18, blue: 0.26, alpha: 1).setFill()
      context.fill(CGRect(origin: .zero, size: size))

      let colors: [UIColor] = [.systemOrange, .systemMint, .systemPink, .systemYellow]
      for (index, color) in colors.enumerated() {
        color.setFill()
        context.fill(CGRect(x: index * 240, y: 0, width: 240, height: 640))
      }

      context.setStrokeColor(UIColor.black.withAlphaComponent(0.45).cgColor)
      context.setLineWidth(3)
      for y in stride(from: 80, through: 560, by: 80) {
        context.move(to: CGPoint(x: 0, y: y))
        context.addLine(to: CGPoint(x: 960, y: y))
      }
      context.strokePath()
      context.setStrokeColor(UIColor.white.cgColor)
      context.setLineWidth(12)
      context.strokeEllipse(in: CGRect(x: 330, y: 170, width: 300, height: 300))

      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 44, weight: .bold),
        .foregroundColor: UIColor.black,
      ]
      for (index, label) in ["LEFT", "CENTER", "RIGHT"].enumerated() {
        (label as NSString).draw(
          at: CGPoint(x: 28 + index * 350, y: 44),
          withAttributes: attributes
        )
      }
    }
  }
}
