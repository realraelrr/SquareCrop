# SquareCrop

An iOS 17+ Swift package for interactive square photo crops. It owns crop geometry,
image preparation and rendering, SwiftUI interaction, and its localized
accessibility strings. It has no application module dependencies.

## Requirements

- iOS/iPadOS 17 or later.
- Swift tools 6.0 or later, using Swift 6 language mode.

## Installation

In Xcode, choose **File → Add Package Dependencies**, enter
`https://github.com/realraelrr/SquareCrop.git`, and select **Up to Next Major
Version** from `0.1.0`. Link the `SquareCrop` product.

For a Swift package consumer, add the dependency and link its product in
`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "MyFeature",
  platforms: [.iOS(.v17)],
  dependencies: [
    .package(url: "https://github.com/realraelrr/SquareCrop.git", from: "0.1.0"),
  ],
  targets: [
    .target(
      name: "MyFeature",
      dependencies: [
        .product(name: "SquareCrop", package: "SquareCrop"),
      ]
    ),
  ]
)
```

## Use

```swift
import SquareCrop
import SwiftUI
import UIKit

struct PhotoCrop: View {
  let source: SquareCropSource
  @State private var crop = SquareCropState()

  var body: some View {
    // A known finite, positive literal.
    try! SquareCropView(source: source, crop: $crop, viewportSide: 236)
  }
}

// Prepare a source once when the selected photo changes.
let source = try SquareCropSource(image: image)
// Encoded image data is also supported:
let decodedSource = try SquareCropSource(data: data)
// Render the current framing to a square UIImage.
let output = try source.render(crop: crop, outputPixelSide: 512)
```

The crop state is independent of the viewport size. Keep the same binding when a
view changes size. Prepare a new source and reset the crop when replacing the
selected photo. The caller owns image selection, presentation, saving, and any
domain-specific styling or guidance.

Source preparation normalizes orientation and image scale, limiting the longest
pixel dimension to 2048. `UIImage` input must be backed by a `CGImage`; a
`CIImage`-only image returns `SquareCropError.unsupportedSource`. Preparation is
synchronous, so perform it in the image-loading work instead of recomputing it
in a view's body. Export returns an upright, scale-1, opaque image with a side
between 1 and 2048 pixels; transparent source pixels are composited over black.
The 2048-pixel limit defines this lightweight component's scope, rather than a
measured device memory guarantee. Extreme aspect ratios or a zoomed crop can
require upsampling; this is not a lossless original-resolution editor.

`SquareCropState` offsets are fractions of the viewport side, positive right and
down. Finite zoom is clamped to 1...4, and geometry clamps offsets to keep the
square inside the prepared source. Nonfinite transforms and invalid output
dimensions return `SquareCropError`. `SquareCropStyle` configures the background,
border, corner radius, and circular guide; the exported image remains square.

`SquareCropView` also has a throwing initializer: zero, negative, or nonfinite
viewport sizes return `SquareCropError.invalidViewportSize`. Use `try` with
normal error handling when accepting configurable dimensions. The example uses
`try!` only for its known valid 236- and 320-point literals.

Accessibility copy ships in English, Spanish, Japanese, Korean, Simplified
Chinese, and Traditional Chinese. `SquareCropAccessibility.localized(locale:)`
resolves copy from the package resource bundle; consumers do not copy strings
into their app catalogs.

## Example

Open `Example/SquareCropExample.xcodeproj` and select the shared
`SquareCropExample` scheme. The app uses only the public `SquareCrop` API. Two
previews at 236 and 320 points share a source and crop binding; a render action
shows the 512-pixel square output. The sample image is drawn by the example and
can be distributed with it. No Photos permission or external images are needed.

The hosted `SquareCropRuntimeResourcesTests` suite resolves English and
Simplified Chinese strings through the public API in the built consumer. It does
not read source catalogs or use `@testable import SquareCrop`.

## Verify

Use a Mac with Xcode, an installed iOS Simulator runtime, and Python 3:

```sh
./Scripts/verify.sh
```

Run the command from this package, or invoke the script by its path from any
directory. To choose a specific available simulator or retain results at a
chosen path:

```sh
SQUARECROP_SIMULATOR_ID="SIMULATOR-UDID" \
SQUARECROP_RESULTS_DIR="/tmp/squarecrop-results" \
./Scripts/verify.sh
```

The script creates an isolated copy of the package and a sibling Example
consumer outside the repository. It runs the package's iOS tests and the
consumer's runtime resource tests, then builds the consumer for generic iOS
Simulator and iOS device destinations with signing disabled. Logs, `.xcresult`
bundles, and the isolated source tree remain in the reported result directory.
`Metadata.log` records the Xcode and Swift versions plus the selected Simulator's
ID, OS version, and OS build. Existing verification artifacts are never overwritten.
Build concurrency defaults to two jobs; `SQUARECROP_JOBS` can override it.

Result validation requires every expected suite to execute at least one passing
case, checks required test identifiers, and rejects failures, skips, and empty
runs. The assertion tool also has a small independent check:

```sh
python3 Scripts/assert-results.py --self-test
```

The iOS Simulator run covers UIKit image decoding/rendering and SwiftUI-facing
code. A host-only `swift test` run cannot establish that coverage. Simulator and
unsigned device builds do not establish physical-device accessibility behavior;
check VoiceOver gestures and actions on a device when integrating the component.
Current development validation uses Xcode 27.0, Swift 6.4, and iOS 27 Simulator.
The declared minimum compiler and iOS 17 runtime have not yet been exercised.
The iOS 17 deployment setting does not substitute for an iOS 17 runtime test.

## License

Licensed under the [Apache License 2.0](LICENSE). See [NOTICE](NOTICE) for attribution.
