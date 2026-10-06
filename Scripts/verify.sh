#!/bin/bash
set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
package_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)

python3 "$script_dir/assert-results.py" --self-test

if [ -n "${SQUARECROP_RESULTS_DIR:-}" ]; then
  mkdir -p "$SQUARECROP_RESULTS_DIR"
  result_dir=$(CDPATH='' cd -- "$SQUARECROP_RESULTS_DIR" && pwd)
else
  result_dir=$(mktemp -d "${TMPDIR:-/tmp}/squarecrop-validation.XXXXXX")
fi

for name in IsolatedConsumer Metadata.log PackageTests.log ConsumerTests.log \
  PackageTests.xcresult ConsumerTests.xcresult PackageDerivedData ConsumerDerivedData \
  ConsumerDeviceDerivedData ConsumerSimulatorBuild.log ConsumerDeviceBuild.log; do
  if [ -e "$result_dir/$name" ]; then
    printf 'error: refusing to overwrite %s\n' "$result_dir/$name" >&2
    exit 1
  fi
done

# Both the copied package and its sibling consumer live outside the source package.
# Only this local package reference changes; no application source is copied.
python3 - "$package_root" "$result_dir/IsolatedConsumer" <<'PY'
from pathlib import Path
import shutil
import stat
import sys

source = Path(sys.argv[1]).resolve()
isolated = Path(sys.argv[2]).resolve()
if isolated == source or source in isolated.parents:
    raise SystemExit("error: validation consumers must live outside the source package")
package = isolated / "SquareCrop"
package.mkdir(parents=True)
shutil.copy2(source / "Package.swift", package / "Package.swift")
for directory in ("Sources", "Tests"):
    shutil.copytree(source / directory, package / directory)
shutil.copytree(
    source / "Example", isolated / "Consumer",
    ignore=shutil.ignore_patterns("xcuserdata", ".DS_Store"),
)
project = isolated / "Consumer/SquareCropExample.xcodeproj/project.pbxproj"
project.chmod(project.stat().st_mode | stat.S_IWUSR)
text = project.read_text()
reference = 'relativePath = "..";'
if text.count(reference) != 1:
    raise SystemExit("error: expected exactly one local SquareCrop package reference")
project.write_text(text.replace(reference, 'relativePath = "../SquareCrop";'))
PY

simulator_id=${SQUARECROP_SIMULATOR_ID:-}
if [ -z "$simulator_id" ]; then
  simulator_id=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
phones = [device for runtime, values in devices.items() if ".iOS-" in runtime
          for device in values if device.get("isAvailable") and device["name"].startswith("iPhone")]
if not phones:
    raise SystemExit("error: no available iPhone Simulator; set SQUARECROP_SIMULATOR_ID")
print(next((device for device in phones if device["state"] == "Booted"), phones[0])["udid"])
')
fi
destination="platform=iOS Simulator,id=$simulator_id"
isolated_package="$result_dir/IsolatedConsumer/SquareCrop"
consumer_project="$result_dir/IsolatedConsumer/Consumer/SquareCropExample.xcodeproj"

{
  xcodebuild -version
  swift --version
  xcrun simctl list --json | python3 -c '
import json, sys
inventory = json.load(sys.stdin)
identifier = sys.argv[1]
matches = [(runtime, device) for runtime, devices in inventory["devices"].items()
           for device in devices if device["udid"] == identifier and device.get("isAvailable")]
if len(matches) != 1:
    raise SystemExit("error: selected Simulator is not available: " + identifier)
runtime_id, device = matches[0]
runtime = next(runtime for runtime in inventory["runtimes"] if runtime["identifier"] == runtime_id)
print("Simulator ID: " + identifier)
print("Simulator name: " + device["name"])
print("Simulator OS: " + runtime["name"] + " " + runtime["version"])
print("Simulator OS build: " + runtime["buildversion"])
print("Simulator runtime: " + runtime_id)
' "$simulator_id"
} 2>&1 | tee "$result_dir/Metadata.log"

(
  cd "$isolated_package"
  xcodebuild -jobs "${SQUARECROP_JOBS:-2}" -scheme SquareCrop -destination "$destination" \
    -derivedDataPath "$result_dir/PackageDerivedData" \
    -resultBundlePath "$result_dir/PackageTests.xcresult" \
    -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test
) 2>&1 | tee "$result_dir/PackageTests.log"

python3 "$script_dir/assert-results.py" "$result_dir/PackageTests.xcresult" \
  --suite SquareCropGeometryTests \
  --suite SquareCropImageTests \
  --suite SquareCropInteractionTests \
  --suite SquareCropLocalizationTests \
  --test SquareCropGeometryTests/testViewportResizePreservesSourceRectAndOriginal236PointComposition \
  --test SquareCropImageTests/testAllEightEXIFAndUIImageOrientationsAgreeAtScaleTwoAndThree \
  --test SquareCropImageTests/testPreviewAndOutputUseSamePreparedSourceAcrossViewportSizes \
  --test SquareCropImageTests/testInvalidViewportSizesReturnTypedErrors \
  --test SquareCropInteractionTests/testInterleavedDragPinchDragPreservesBothAcceptedComponents \
  --test SquareCropInteractionTests/testPinchClampRebasesActiveDragOnBothAxesAndEndingOrders \
  --test SquareCropInteractionTests/testResizeSourceReplacementAndDisappearRejectLateUpdates \
  --test SquareCropLocalizationTests/testSixLocaleResourcesHaveCompleteKeysAndZoomPlaceholders

xcodebuild -jobs "${SQUARECROP_JOBS:-2}" -project "$consumer_project" -scheme SquareCropExample \
  -destination "$destination" \
  -derivedDataPath "$result_dir/ConsumerDerivedData" \
  -resultBundlePath "$result_dir/ConsumerTests.xcresult" \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test \
  2>&1 | tee "$result_dir/ConsumerTests.log"

python3 "$script_dir/assert-results.py" "$result_dir/ConsumerTests.xcresult" \
  --suite SquareCropRuntimeResourcesTests \
  --test SquareCropRuntimeResourcesTests/testEnglishResourcesResolveFromTheConsumedPackage \
  --test SquareCropRuntimeResourcesTests/testSimplifiedChineseResourcesResolveFromTheConsumedPackage

xcodebuild -jobs "${SQUARECROP_JOBS:-2}" -project "$consumer_project" -scheme SquareCropExample \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$result_dir/ConsumerDerivedData" \
  CODE_SIGNING_ALLOWED=NO build \
  2>&1 | tee "$result_dir/ConsumerSimulatorBuild.log"

xcodebuild -jobs "${SQUARECROP_JOBS:-2}" -project "$consumer_project" -scheme SquareCropExample \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$result_dir/ConsumerDeviceDerivedData" \
  CODE_SIGNING_ALLOWED=NO build \
  2>&1 | tee "$result_dir/ConsumerDeviceBuild.log"

printf 'SquareCrop validation passed; results and independent consumer: %s\n' "$result_dir"
